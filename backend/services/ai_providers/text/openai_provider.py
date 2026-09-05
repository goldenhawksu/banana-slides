"""
OpenAI SDK implementation for text generation
"""
import logging
import httpx
from openai import OpenAI
from .base import TextProvider
from config import get_config

logger = logging.getLogger(__name__)


class _NeutralUserAgentTransport(httpx.HTTPTransport):
    """Override the OpenAI SDK's User-Agent to avoid subscription-account proxy blocks."""
    def handle_request(self, request):
        request.headers["user-agent"] = "python-httpx/0.27.0"
        return super().handle_request(request)


class OpenAITextProvider(TextProvider):
    """Text generation using OpenAI SDK (compatible with Gemini via proxy)"""

    def __init__(self, api_key: str, api_base: str = None, model: str = "gemini-3-flash-preview"):
        """
        Initialize OpenAI text provider

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
    
    def generate_text(self, prompt: str, thinking_budget: int = 1000) -> str:
        """
        Generate text using OpenAI SDK
        
        Args:
            prompt: The input prompt
            thinking_budget: Not used in OpenAI format, kept for interface compatibility
            
        Returns:
            Generated text
        """
        response = self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "user", "content": prompt}
            ]
        )
        return response.choices[0].message.content
