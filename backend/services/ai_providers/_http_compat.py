"""
Shared HTTP client helpers for OpenAI-compatible providers.

本模块为本仓库相对上游的定制补丁，独立成文件以便上游同步时不产生冲突。
"""
import httpx


class _NeutralUserAgentTransport(httpx.HTTPTransport):
    """Override the OpenAI SDK's User-Agent to avoid subscription-account proxy blocks."""

    def handle_request(self, request):
        request.headers["user-agent"] = "python-httpx/0.27.0"
        return super().handle_request(request)


def neutral_ua_client() -> httpx.Client:
    """Build an httpx client whose User-Agent does not identify the OpenAI SDK.

    某些订阅账号池网关（如 sub2api）会拦截 UA 为 ``OpenAI/Python`` 的请求并返回 403，
    此处统一改写为通用 UA。
    """
    return httpx.Client(transport=_NeutralUserAgentTransport())
