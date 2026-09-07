# Banana Slides 便携版

## 🚀 快速开始

### 一键启动

```bash
双击运行: portable\一键启动.bat
```

脚本会自动完成:
1. ✅ 检查运行环境 (uv, Node.js)
2. ✅ 创建默认配置 (.env)
3. ✅ 安装依赖 (Python 3.12 自动下载)
4. ✅ 启动服务
5. ✅ 打开浏览器 (http://localhost:3000)

---

## 📋 环境要求

### 必需软件

**推荐方案** (最简单):
- **Node.js 18+** → https://nodejs.org/
- **uv** → `powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"`

> **说明**: uv 会自动下载并管理 Python 3.12,无需手动安装 Python!

**传统方案**:
- Python 3.10+ → https://www.python.org/downloads/
- Node.js 18+ → https://nodejs.org/
- uv → `pip install uv`

---

## 🎮 管理菜单

功能更全的管理工具:

```powershell
右键运行: portable\menu.ps1
选择"使用 PowerShell 运行"
```

**主要功能**:
- [1] 启动服务
- [2] 停止服务
- [3] 重启服务
- [4] 查看状态
- [5] 配置环境 (编辑 .env)
- [6] 安装依赖
- [7] 清理数据
- [P] 配置代理 (国内用户推荐)

---

## ⚙️ 配置说明

### 默认配置 (开箱即用)

首次启动会自动从 `.env.default` 复制默认配置,包含免费可用的 API:

```ini
# 免费代理服务 (无需申请)
GOOGLE_API_BASE=https://gpt-load.spdt.work/proxy/nbp-pool
GOOGLE_API_KEY=sk-gpt-load-nbp-pool-free-key
```

### 自定义配置 (可选)

编辑项目根目录的 `.env` 文件:

```ini
# 使用官方 API
GOOGLE_API_BASE=https://generativelanguage.googleapis.com
GOOGLE_API_KEY=你的API密钥

# 或使用其他代理
GOOGLE_API_BASE=https://aihubmix.com/gemini
GOOGLE_API_KEY=你的API密钥
```

**获取 API Key**: https://aistudio.google.com/apikey

---

## 🌐 代理配置 (国内用户)

如果遇到依赖安装失败或网络问题:

**使用菜单配置** (推荐):
1. 运行 `portable\menu.ps1`
2. 选择 [P] 配置代理
3. 选择 [4] 使用默认代理

**手动配置**:

编辑 `.proxy` 文件:
```ini
PROXY_ENABLED=true
PROXY_SERVER=socks://socks.spdt.work:63080
```

---

## ❓ 常见问题

### 1. 找不到 uv 或 Python?

**安装 uv (推荐)**:
```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

uv 会自动管理 Python 3.12!

### 2. 找不到 Node.js?

下载安装: https://nodejs.org/ (选择 LTS 版本)

### 3. 依赖安装失败?

- **国内用户**: 配置代理 (菜单 → [P])
- **使用镜像**: `npm config set registry https://registry.npmmirror.com/`

### 4. 端口被占用?

- 默认端口: 后端 5000, 前端 3000
- 查找占用: `netstat -ano | findstr :5000`

### 5. API 调用失败?

- 检查 `.env` 中的 API Key 是否正确
- 尝试使用代理地址: `https://aihubmix.com/gemini`

---

## 📂 文件说明

| 文件 | 用途 |
|------|------|
| 一键启动.bat | Windows 一键启动脚本 |
| menu.ps1 | PowerShell 管理菜单 |
| .env.default | 默认配置模板 (自动复制到根目录) |
| .proxy.default | 代理配置模板 |
| 使用说明.txt | 详细使用指南 |
| build-release.ps1 | 打包脚本 (开发者用) |

---

## 🛠️ 开发者打包

创建便携版 ZIP 包:

```powershell
cd portable
.\build-release.ps1                    # 默认版本 0.3.0
.\build-release.ps1 -Version "1.0.0"  # 指定版本
```

输出: `releases/banana-slides-portable-vX.X.X.zip`

详细说明: `docs/便携版打包说明.md`

---

## 📖 详细文档

- **使用说明**: `portable/使用说明.txt`
- **打包说明**: `docs/便携版打包说明.md`
- **测试报告**: `docs/一键启动脚本测试报告.md`
- **项目主页**: https://github.com/Anionex/banana-slides

---

## 💡 核心特性

- 🚀 **智能生成** - AI 自动生成大纲、描述和图片
- 🎨 **风格统一** - 支持模板图和素材参考
- ⚡ **批量处理** - 并发生成,效率更高
- 🔧 **灵活配置** - 支持多种 AI 提供商
- 📦 **开箱即用** - 默认配置即可使用

---

## 📝 许可证

CC BY-NC-SA 4.0 - 非商业用途开源

---

**祝使用愉快!** 🎉

如有问题,欢迎反馈: https://github.com/Anionex/banana-slides/issues
