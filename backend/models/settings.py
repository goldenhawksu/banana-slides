"""Settings model"""
import json
from datetime import datetime, timezone
from . import db


class Settings(db.Model):
    """
    Settings model - stores global application settings
    """
    __tablename__ = 'settings'

    id = db.Column(db.Integer, primary_key=True, default=1)
    ai_provider_format = db.Column(db.String(20), nullable=False, default='gemini')  # AI提供商格式: openai, gemini
    api_base_url = db.Column(db.String(500), nullable=True)  # API基础URL
    api_key = db.Column(db.String(500), nullable=True)  # API密钥
    image_resolution = db.Column(db.String(20), nullable=False, default='2K')  # 图像清晰度: 1K, 2K, 4K
    image_aspect_ratio = db.Column(db.String(10), nullable=False, default='16:9')  # 图像比例: 16:9, 4:3, 1:1
    max_description_workers = db.Column(db.Integer, nullable=False, default=5)  # 描述生成最大工作线程数
    max_image_workers = db.Column(db.Integer, nullable=False, default=8)  # 图像生成最大工作线程数

    # 新增：大模型与 MinerU 相关可视化配置（可在设置页中编辑）
    text_model = db.Column(db.String(100), nullable=True)  # 文本大模型名称（覆盖 Config.TEXT_MODEL）
    image_model = db.Column(db.String(100), nullable=True)  # 图片大模型名称（覆盖 Config.IMAGE_MODEL）
    mineru_api_base = db.Column(db.String(255), nullable=True)  # MinerU 服务地址（覆盖 Config.MINERU_API_BASE）
    mineru_token = db.Column(db.String(500), nullable=True)  # MinerU API Token（覆盖 Config.MINERU_TOKEN）
    image_caption_model = db.Column(db.String(100), nullable=True)  # 图片识别模型（覆盖 Config.IMAGE_CAPTION_MODEL）
    output_language = db.Column(db.String(10), nullable=False, default='zh')  # 输出语言偏好（zh, en, ja, auto）
    # 每个 provider 的完整参数集（JSON），切换时恢复各自上次保存的值
    openai_config = db.Column(db.Text, nullable=True)
    gemini_config = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    # ── provider config helpers ──────────────────────────────────────────────

    def get_provider_config(self, provider: str) -> dict:
        """Return the stored config dict for a provider, or {} if not yet saved."""
        raw = self.openai_config if provider == 'openai' else self.gemini_config
        if raw:
            try:
                return json.loads(raw)
            except (json.JSONDecodeError, TypeError):
                pass
        return {}

    def save_provider_config(self, provider: str, cfg: dict) -> None:
        """Persist a provider config dict (including api_key) as JSON."""
        payload = json.dumps(cfg, ensure_ascii=False)
        if provider == 'openai':
            self.openai_config = payload
        else:
            self.gemini_config = payload

    @staticmethod
    def _safe_config_public(cfg: dict) -> dict:
        """Strip the actual api_key, expose only its length."""
        return {
            'api_base_url':        cfg.get('api_base_url', ''),
            'api_key_length':      len(cfg.get('api_key') or ''),
            'text_model':          cfg.get('text_model', ''),
            'image_model':         cfg.get('image_model', ''),
            'image_caption_model': cfg.get('image_caption_model', ''),
        }

    def to_dict(self):
        """Convert to dictionary"""
        # 激活 provider 的参数集 = 主列（权威来源，始终最新）
        # 非激活 provider 的参数集 = JSON blob（上次保存值）
        active = self.ai_provider_format
        active_cfg = {
            'api_base_url':        self.api_base_url,
            'api_key':             self.api_key,
            'text_model':          self.text_model,
            'image_model':         self.image_model,
            'image_caption_model': self.image_caption_model,
        }
        openai_cfg = active_cfg if active == 'openai' else self.get_provider_config('openai')
        gemini_cfg = active_cfg if active == 'gemini' else self.get_provider_config('gemini')
        return {
            'id': self.id,
            'ai_provider_format': self.ai_provider_format,
            'api_base_url': self.api_base_url,
            'api_key_length': len(self.api_key) if self.api_key else 0,
            'image_resolution': self.image_resolution,
            'image_aspect_ratio': self.image_aspect_ratio,
            'max_description_workers': self.max_description_workers,
            'max_image_workers': self.max_image_workers,
            'text_model': self.text_model,
            'image_model': self.image_model,
            'mineru_api_base': self.mineru_api_base,
            'mineru_token_length': len(self.mineru_token) if self.mineru_token else 0,
            'image_caption_model': self.image_caption_model,
            'output_language': self.output_language,
            # 各 provider 上次保存的参数集（不含真实 key）
            'provider_configs': {
                'openai': self._safe_config_public(openai_cfg) if openai_cfg else None,
                'gemini': self._safe_config_public(gemini_cfg) if gemini_cfg else None,
            },
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
        }

    @staticmethod
    def get_settings():
        """
        Get or create the single settings instance.

        - 首次创建时，用 Config（也就是 .env）里的值初始化，作为“系统默认值”
        - 之后所有读写都只走数据库，env 只影响初始化/重置逻辑
        """
        # 延迟导入，避免循环依赖
        from config import Config

        settings = Settings.query.first()
        if settings and settings.ai_provider_format != Config.AI_PROVIDER_FORMAT:
            # AI_PROVIDER_FORMAT 在 .env 中被切换，自动同步模型、凭据和语言
            settings.ai_provider_format = Config.AI_PROVIDER_FORMAT
            settings.text_model = Config.TEXT_MODEL
            settings.image_model = Config.IMAGE_MODEL
            settings.image_caption_model = Config.IMAGE_CAPTION_MODEL
            settings.output_language = Config.OUTPUT_LANGUAGE
            if (Config.AI_PROVIDER_FORMAT or '').lower() == 'openai':
                settings.api_base_url = Config.OPENAI_API_BASE or None
                settings.api_key = Config.OPENAI_API_KEY or None
            else:
                settings.api_base_url = Config.GOOGLE_API_BASE or None
                settings.api_key = Config.GOOGLE_API_KEY or None
            db.session.commit()
        if not settings:

            # 根据 AI_PROVIDER_FORMAT 选择默认 Provider 的 env 配置
            if (Config.AI_PROVIDER_FORMAT or '').lower() == 'openai':
                default_api_base = Config.OPENAI_API_BASE or None
                default_api_key = Config.OPENAI_API_KEY or None
            else:
                # 默认为 gemini（Google）
                default_api_base = Config.GOOGLE_API_BASE or None
                default_api_key = Config.GOOGLE_API_KEY or None

            settings = Settings(
                ai_provider_format=Config.AI_PROVIDER_FORMAT,
                api_base_url=default_api_base,
                api_key=default_api_key,
                image_resolution=Config.DEFAULT_RESOLUTION,
                image_aspect_ratio=Config.DEFAULT_ASPECT_RATIO,
                max_description_workers=Config.MAX_DESCRIPTION_WORKERS,
                max_image_workers=Config.MAX_IMAGE_WORKERS,
                text_model=Config.TEXT_MODEL,
                image_model=Config.IMAGE_MODEL,
                mineru_api_base=Config.MINERU_API_BASE,
                mineru_token=Config.MINERU_TOKEN,
                image_caption_model=Config.IMAGE_CAPTION_MODEL,
                output_language='zh',  # 默认中文
            )
            settings.id = 1
            db.session.add(settings)
            db.session.commit()
        return settings

    def __repr__(self):
        return f'<Settings id={self.id}>'
