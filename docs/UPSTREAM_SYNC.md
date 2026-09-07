# 上游同步指南

本仓库 fork 自 [Anionex/banana-slides](https://github.com/Anionex/banana-slides)，
保留了少量本地定制。本文档记录定制点与同步流程，便于快速合并上游变更。

## 远程配置

```bash
git remote -v
# origin    https://github.com/goldenhawksu/banana-slides   (自己的 fork)
# upstream  https://github.com/Anionex/banana-slides.git     (上游)
```

若 `upstream` 不存在：

```bash
git remote add upstream https://github.com/Anionex/banana-slides.git
```

## 本仓库相对上游的定制点

改动刻意保持最小，且尽量集中在自有文件中，以降低合并冲突。

| 文件 | 类型 | 说明 |
|------|------|------|
| `backend/services/ai_providers/_http_compat.py` | 新增 | 提供 `neutral_ua_client()`，改写 OpenAI SDK 的 User-Agent |
| `backend/services/ai_providers/text/openai_provider.py` | 修改 2 行 | 1 行 import + `http_client=neutral_ua_client()` |
| `backend/services/ai_providers/image/openai_provider.py` | 修改 2 行 | 同上 |
| `.gitattributes` | 新增 | 强制 `*.bat` / `*.cmd` 使用 CRLF |
| `portable/` | 新增目录 | 便携版启动脚本，上游没有此目录 |

### UA 补丁的原因

部分订阅账号池网关（如 sub2api）会拦截 `User-Agent: OpenAI/Python/*` 的请求
并返回 `403 Your request was blocked`。`_http_compat.py` 将 UA 改写为
`python-httpx/0.27.0` 后即可正常调用。

若将来上游自身支持了自定义 http_client 或 UA，可直接删除此补丁。

## 同步流程

```bash
# 1. 拉取上游最新代码
git fetch upstream

# 2. 查看分叉情况（左=上游独有，右=我方独有）
git rev-list --left-right --count upstream/main...main

# 3. 合并
git checkout main
git merge upstream/main
```

### 冲突处理

只有以下两个文件可能冲突，处理方式固定：

**`backend/services/ai_providers/{text,image}/openai_provider.py`**

保留上游全部内容，只需确认这两行仍在：

```python
from .._http_compat import neutral_ua_client     # import 区
...
    http_client=neutral_ua_client()               # OpenAI(...) 参数
```

冲突时优先采用上游版本，再重新加回这两行即可。

### 合并后验证

```bash
# 依赖同步
uv sync

# 数据库迁移（确认单一 head，无分叉）
cd backend && uv run alembic heads          # 应只输出一行
uv run alembic upgrade head

# UA 补丁是否生效（需 .env 中配置了 OpenAI 系凭据）
cd backend && uv run python -c "
import sys; sys.path.insert(0, '.')
from dotenv import load_dotenv; load_dotenv('../.env', override=True)
import os
from services.ai_providers.text.openai_provider import OpenAITextProvider
p = OpenAITextProvider(os.getenv('OPENAI_API_KEY'), os.getenv('OPENAI_API_BASE'), os.getenv('TEXT_MODEL'))
print(p.generate_text('Reply with exactly: ok'))
"
```

### migration 多 head 的处理

新增 migration 时，`down_revision` 必须指向当前**真实链尾**，而非看起来最近的
那个 revision，否则会产生多 head 并导致启动报错：

```
Multiple head revisions are present for given argument 'head'
```

确认链尾：

```bash
cd backend && uv run alembic heads
```
