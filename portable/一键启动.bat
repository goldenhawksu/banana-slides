@echo off
:: 强制使用UTF-8编码,避免中文乱码
chcp 65001 >nul 2>&1
:: 设置控制台字体为支持中文的字体
if exist "%windir%\system32\chcp.com" (
    for /f "tokens=*" %%i in ('chcp') do set "original_codepage=%%i"
)
title Banana Slides - 一键启动
setlocal EnableDelayedExpansion

echo.
echo ========================================
echo.
echo   Banana Slides 便携版启动器
echo.
echo ========================================
echo.

REM 获取脚本所在目录
set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%.."

REM 检查必要的环境
echo [1/5] 检查运行环境...

REM 优先检查 uv (uv 会自动管理 Python 环境)
uv --version >nul 2>&1
if %errorlevel% equ 0 (
    echo   [✓] uv 已安装 - 将自动管理 Python 环境
    set "USE_UV_PYTHON=true"
) else (
    set "USE_UV_PYTHON=false"
    REM 如果没有 uv,则检查 Python
    python --version >nul 2>&1
    if %errorlevel% neq 0 (
        echo [错误] 未找到 uv 或 Python!
        echo.
        echo 请选择以下任一方式:
        echo.
        echo   方式1 - 安装 uv (推荐^):
        echo   powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
        echo.
        echo   方式2 - 安装 Python 3.10+:
        echo   https://www.python.org/downloads/
        echo.
        pause
        exit /b 1
    )
    echo   [✓] Python 已安装
)

REM 检查 Node.js
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 未找到 Node.js! 请先安装 Node.js 18+
    echo.
    echo 下载地址: https://nodejs.org/
    pause
    exit /b 1
)
echo   [✓] Node.js 已安装

echo.
echo [2/5] 检查代理配置...
set "PROXY_ENABLED=false"
set "PROXY_SERVER="

REM 读取代理配置文件
if exist "%PROJECT_ROOT%\.proxy" (
    for /f "tokens=1,* delims==" %%a in ('type "%PROJECT_ROOT%\.proxy" ^| findstr /v "^#"') do (
        if "%%a"=="PROXY_ENABLED" set "PROXY_ENABLED=%%b"
        if "%%a"=="PROXY_SERVER" set "PROXY_SERVER=%%b"
    )
)

REM 如果启用代理，设置环境变量
if /i "%PROXY_ENABLED%"=="true" (
    echo   [提示] 检测到代理配置已启用
    echo   代理服务器: %PROXY_SERVER%

    REM 设置代理环境变量
    set "HTTP_PROXY=%PROXY_SERVER%"
    set "HTTPS_PROXY=%PROXY_SERVER%"
    set "ALL_PROXY=%PROXY_SERVER%"

    echo   [成功] 代理环境变量已设置
) else (
    echo   [提示] 代理未启用，使用直连
)

echo.
echo [3/5] 检查 .env 配置文件...
if not exist "%PROJECT_ROOT%\.env" (
    echo [警告] 未找到 .env 文件!
    echo.

    REM 按优先级查找配置模板文件
    REM 优先级: 1. portable\.env.default  2. .env.example  3. 手动创建
    if exist "%SCRIPT_DIR%.env.default" (
        echo 正在从 portable\.env.default 复制默认配置...
        copy "%SCRIPT_DIR%.env.default" "%PROJECT_ROOT%\.env" >nul
        if exist "%PROJECT_ROOT%\.env" (
            echo   [成功] 已创建 .env 文件 (使用 portable\.env.default^)
        ) else (
            echo [错误] 复制配置文件失败!
            pause
            exit /b 1
        )
    ) else (
        if exist "%PROJECT_ROOT%\.env.example" (
            echo [提示] portable\.env.default 不存在,使用备选方案
            echo 正在从 .env.example 复制...
            copy "%PROJECT_ROOT%\.env.example" "%PROJECT_ROOT%\.env" >nul
            if exist "%PROJECT_ROOT%\.env" (
                echo   [成功] 已创建 .env 文件 (使用 .env.example^)
            ) else (
                echo [错误] 复制配置文件失败!
                pause
                exit /b 1
            )
        ) else (
            echo [错误] 未找到配置模板文件!
            echo.
            echo 缺少以下文件:
            echo   1. portable\.env.default (推荐^)
            echo   2. .env.example (备选^)
            echo.
            echo 请手动创建 .env 文件,包含以下必需配置:
            echo.
            echo   AI_PROVIDER_FORMAT=gemini
            echo   GOOGLE_API_BASE=https://your-api-endpoint
            echo   GOOGLE_API_KEY=your-api-key
            echo   TEXT_MODEL=gemini-3-flash-preview
            echo   IMAGE_MODEL=gemini-3-pro-image-preview
            echo.
            echo 详细配置说明请参考项目文档。
            echo.
            pause
            exit /b 1
        )
    )

    echo.
    echo [提示] 默认配置已可直接使用 (使用免费代理服务)
    echo.
    echo 如需自定义配置,可以编辑 .env 文件:
    echo   - GOOGLE_API_KEY: 更换为你的API密钥
    echo   - GOOGLE_API_BASE: 更换为你的代理地址
    echo.
    set /p edit_config="是否现在编辑配置文件? (Y=是, N=否,使用默认): "
    if /i "%edit_config%"=="Y" (
        notepad "%PROJECT_ROOT%\.env"
        echo.
        echo 编辑完成后,按任意键继续...
        pause >nul
    )
) else (
    echo   [✓] .env 配置文件已存在
)

echo.
echo [4/5] 安装/检查依赖...

REM 检查后端依赖 (uv 会在项目根目录创建 .venv)
if not exist "%PROJECT_ROOT%\.venv" (
    echo   正在安装后端依赖...
    echo   [提示] uv 将自动下载并安装 Python 3.12
    cd /d "%PROJECT_ROOT%\backend"
    REM 指定 Python 版本为 3.12 (uv 会自动下载)
    uv sync --python 3.12
    REM 不依赖 errorlevel,改为检查虚拟环境是否创建成功
    if not exist "%PROJECT_ROOT%\.venv" (
        echo [错误] 后端依赖安装失败! 未找到虚拟环境目录
        pause
        exit /b 1
    )
    echo   [✓] 后端依赖安装完成
) else (
    echo   [✓] 后端依赖已安装
)

REM 检查前端依赖
if not exist "%PROJECT_ROOT%\frontend\node_modules" (
    echo   正在安装前端依赖...
    cd /d "%PROJECT_ROOT%\frontend"
    call npm install
    REM 同样不依赖 errorlevel
    if not exist "%PROJECT_ROOT%\frontend\node_modules" (
        echo [错误] 前端依赖安装失败! 未找到 node_modules 目录
        pause
        exit /b 1
    )
    echo   [✓] 前端依赖安装完成
) else (
    echo   [✓] 前端依赖已安装
)

echo.
echo [5/5] 启动后端服务...
cd /d "%PROJECT_ROOT%\backend"

REM 如果启用了代理，在启动命令中传递代理环境变量
if /i "%PROXY_ENABLED%"=="true" (
    start "Banana Slides - 后端" cmd /k "set HTTP_PROXY=%PROXY_SERVER%&& set HTTPS_PROXY=%PROXY_SERVER%&& set ALL_PROXY=%PROXY_SERVER%&& uv run alembic upgrade head && uv run python app.py"
) else (
    start "Banana Slides - 后端" cmd /k "uv run alembic upgrade head && uv run python app.py"
)

REM 等待后端启动
echo   等待后端启动 (5秒)...
timeout /t 5 /nobreak >nul

echo.
echo [6/6] 启动前端服务...
cd /d "%PROJECT_ROOT%\frontend"

REM 如果启用了代理，在启动命令中传递代理环境变量
if /i "%PROXY_ENABLED%"=="true" (
    start "Banana Slides - 前端" cmd /k "set HTTP_PROXY=%PROXY_SERVER%&& set HTTPS_PROXY=%PROXY_SERVER%&& set ALL_PROXY=%PROXY_SERVER%&& npm run dev"
) else (
    start "Banana Slides - 前端" cmd /k "npm run dev"
)

REM 等待前端启动
echo   等待前端启动 (3秒)...
timeout /t 3 /nobreak >nul

echo.
echo ========================================
echo.
echo   [启动完成!]
echo.
echo   后端服务: http://localhost:5000
echo   前端页面: http://localhost:3000
echo.
echo   正在打开浏览器...
echo.
echo ========================================
echo.

REM 打开浏览器
timeout /t 2 /nobreak >nul
start http://localhost:3000

echo.
echo 提示: 关闭此窗口不会停止服务；要停止服务,请关闭两个命令行窗口
echo.
pause
endlocal
exit /b 0
