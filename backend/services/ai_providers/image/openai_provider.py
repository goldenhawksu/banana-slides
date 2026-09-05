"""
OpenAI SDK implementation for image generation
"""
import logging
import base64
import re
import httpx
import requests
from io import BytesIO
from typing import Optional, List
from openai import OpenAI
from PIL import Image
from .base import ImageProvider
from config import get_config

logger = logging.getLogger(__name__)


class _NeutralUserAgentTransport(httpx.HTTPTransport):
    """Override the OpenAI SDK's User-Agent to avoid subscription-account proxy blocks."""
    def handle_request(self, request):
        request.headers["user-agent"] = "python-httpx/0.27.0"
        return super().handle_request(request)


class OpenAIImageProvider(ImageProvider):
    """Image generation using OpenAI SDK (compatible with Gemini via proxy)"""

    def __init__(self, api_key: str, api_base: str = None, model: str = "gemini-3-pro-image-preview"):
        """
        Initialize OpenAI image provider

        Args:
            api_key: API key
            api_base: API base URL (e.g., https://aihubmix.com/v1)
            model: Model name to use
        """
        cfg = get_config()
        http_client = httpx.Client(
            transport=_NeutralUserAgentTransport(),
            timeout=cfg.OPENAI_TIMEOUT,
        )
        self.client = OpenAI(
            api_key=api_key,
            base_url=api_base,
            http_client=http_client,
            max_retries=cfg.OPENAI_MAX_RETRIES,
        )
        self.model = model
        # None = unknown, True = images/generations, False = chat.completions
        self._use_images_api: Optional[bool] = None
    
    def _encode_image_to_base64(self, image: Image.Image) -> str:
        """
        Encode PIL Image to base64 string
        
        Args:
            image: PIL Image object
            
        Returns:
            Base64 encoded string
        """
        buffered = BytesIO()
        # Convert to RGB if necessary (e.g., RGBA images)
        if image.mode in ('RGBA', 'LA', 'P'):
            image = image.convert('RGB')
        image.save(buffered, format="JPEG", quality=95)
        return base64.b64encode(buffered.getvalue()).decode('utf-8')
    
    _ASPECT_RATIO_TO_SIZE = {
        "16:9": "1536x1024",
        "4:3":  "1536x1024",
        "1:1":  "1024x1024",
        "9:16": "1024x1536",
        "3:4":  "1024x1536",
    }

    def _aspect_ratio_to_size(self, aspect_ratio: str) -> str:
        return self._ASPECT_RATIO_TO_SIZE.get(aspect_ratio, "1024x1024")

    def _generate_via_images_api(self, prompt: str, aspect_ratio: str) -> Image.Image:
        """Use /v1/images/generations endpoint (e.g. gpt-image-2)."""
        size = self._aspect_ratio_to_size(aspect_ratio)
        logger.debug(f"Calling images/generations API, model={self.model}, size={size}")
        response = self.client.images.generate(
            model=self.model,
            prompt=prompt,
            n=1,
            size=size,
            response_format="b64_json",
        )
        b64_data = response.data[0].b64_json
        image_data = base64.b64decode(b64_data)
        image = Image.open(BytesIO(image_data))
        logger.debug(f"Successfully generated image via images/generations: {image.size}, {image.mode}")
        return image

    def _extract_image_from_chat_message(self, message) -> Optional[Image.Image]:
        """Extract image from a chat.completions response message."""
        # Try multi_mod_content first (custom format from some proxies)
        if hasattr(message, 'multi_mod_content') and message.multi_mod_content:
            for part in message.multi_mod_content:
                if "text" in part:
                    logger.debug(f"Response text: {part['text'][:100]}")
                if "inline_data" in part:
                    image_data = base64.b64decode(part["inline_data"]["data"])
                    image = Image.open(BytesIO(image_data))
                    logger.debug(f"Extracted image via multi_mod_content: {image.size}")
                    return image

        if not (hasattr(message, 'content') and message.content):
            return None

        # Content is a list of parts
        if isinstance(message.content, list):
            for part in message.content:
                url = None
                if isinstance(part, dict):
                    if part.get('type') == 'image_url':
                        url = part.get('image_url', {}).get('url', '')
                    elif part.get('type') == 'text':
                        logger.debug(f"Response text: {part.get('text', '')[:100]}")
                elif hasattr(part, 'type'):
                    if part.type == 'image_url':
                        image_url = getattr(part, 'image_url', {})
                        url = image_url.get('url', '') if isinstance(image_url, dict) else getattr(image_url, 'url', '')
                if url and url.startswith('data:image'):
                    image_data = base64.b64decode(url.split(',', 1)[1])
                    image = Image.open(BytesIO(image_data))
                    logger.debug(f"Extracted image from content list: {image.size}")
                    return image

        # Content is a string — try URLs and base64
        if isinstance(message.content, str):
            content_str = message.content
            logger.debug(f"Response content (string): {content_str[:200]}")

            for pattern, is_url in [
                (r'!\[.*?\]\((https?://[^\s\)]+)\)', True),
                (r'(https?://[^\s\)\]]+\.(?:png|jpg|jpeg|gif|webp|bmp)(?:\?[^\s\)\]]*)?)', True),
            ]:
                matches = re.findall(pattern, content_str, re.IGNORECASE)
                if matches:
                    try:
                        resp = requests.get(matches[0], timeout=30, stream=True)
                        resp.raise_for_status()
                        image = Image.open(BytesIO(resp.content))
                        image.load()
                        logger.debug(f"Downloaded image from URL: {image.size}")
                        return image
                    except Exception as e:
                        logger.warning(f"Failed to download image from URL: {e}")

            b64_matches = re.findall(r'data:image/[^;]+;base64,([A-Za-z0-9+/=]+)', content_str)
            if b64_matches:
                try:
                    image_data = base64.b64decode(b64_matches[0])
                    image = Image.open(BytesIO(image_data))
                    logger.debug(f"Extracted base64 image from string: {image.size}")
                    return image
                except Exception as e:
                    logger.warning(f"Failed to decode base64 image: {e}")

        return None

    def _generate_via_chat_completions(
        self,
        prompt: str,
        ref_images: Optional[List[Image.Image]],
        aspect_ratio: str,
    ) -> Image.Image:
        """Use chat.completions with modalities=["text","image"]."""
        content = []
        if ref_images:
            for ref_img in ref_images:
                b64 = self._encode_image_to_base64(ref_img)
                content.append({"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}})
        content.append({"type": "text", "text": prompt})

        logger.debug(f"Calling chat.completions, model={self.model}, ref_images={len(ref_images) if ref_images else 0}")
        response = self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": f"aspect_ratio={aspect_ratio}"},
                {"role": "user", "content": content},
            ],
            modalities=["text", "image"],
        )
        message = response.choices[0].message
        image = self._extract_image_from_chat_message(message)
        if image is None:
            raise ValueError(
                f"No image found in chat.completions response "
                f"(content type: {type(getattr(message, 'content', None)).__name__})"
            )
        return image

    def generate_image(
        self,
        prompt: str,
        ref_images: Optional[List[Image.Image]] = None,
        aspect_ratio: str = "16:9",
        resolution: str = "2K"
    ) -> Optional[Image.Image]:
        """
        Generate image using OpenAI SDK.

        Tries chat.completions with modalities first; if that fails (e.g. model only
        supports /v1/images/generations), falls back to the images API automatically.
        """
        # Fast path: already know which method works for this model
        if self._use_images_api is True:
            return self._generate_via_images_api(prompt, aspect_ratio)
        if self._use_images_api is False:
            return self._generate_via_chat_completions(prompt, ref_images, aspect_ratio)

        # First call: probe which method the model supports
        try:
            image = self._generate_via_chat_completions(prompt, ref_images, aspect_ratio)
            self._use_images_api = False
            return image
        except Exception as chat_err:
            logger.warning(f"chat.completions failed ({chat_err}), falling back to images/generations (will skip chat next time)")
            try:
                image = self._generate_via_images_api(prompt, aspect_ratio)
                self._use_images_api = True
                return image
            except Exception as images_err:
                error_detail = (
                    f"Error generating image with OpenAI (model={self.model}): "
                    f"chat.completions failed: {chat_err}; "
                    f"images/generations failed: {images_err}"
                )
                logger.error(error_detail)
                raise Exception(error_detail) from images_err
