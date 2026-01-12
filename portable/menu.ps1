# Banana Slides - 主菜单 (便携版)
# PowerShell Script for Windows

# 设置编码
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 获取脚本目录
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Join-Path $scriptPath ".."

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
    Write-Host "  Banana Slides 便携版管理工具" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  请选择操作:" -ForegroundColor White
    Write-Host ""
    Write-Host "  [1] 启动服务" -ForegroundColor White
    Write-Host "  [2] 停止服务" -ForegroundColor White
    Write-Host "  [3] 重启服务" -ForegroundColor White
    Write-Host "  [4] 查看状态" -ForegroundColor White
    Write-Host "  [5] 配置环境" -ForegroundColor White
    Write-Host "  [6] 安装依赖" -ForegroundColor White
    Write-Host "  [7] 清理数据" -ForegroundColor White
    Write-Host "  [8] 打开浏览器" -ForegroundColor White
    Write-Host "  [9] 更新所有代码" -ForegroundColor White
    Write-Host "  [P] 配置代理" -ForegroundColor Yellow
    Write-Host "  [0] 退出" -ForegroundColor White
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Start-Services {
    Clear-Host
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  启动服务" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Set-Location $projectRoot

    # 读取代理配置
    $proxyEnabled = $false
    $proxyServer = ""
    $proxyFile = Join-Path $projectRoot ".proxy"

    if (Test-Path $proxyFile) {
        $content = Get-Content $proxyFile -Raw
        if ($content -match 'PROXY_ENABLED=true') {
            $proxyEnabled = $true
        }
        if ($content -match 'PROXY_SERVER=(.+)') {
            $proxyServer = $matches[1].Trim()
        }
    }

    # 构建启动命令
    $backendCmd = "cd '$projectRoot\backend'; "
    $frontendCmd = "cd '$projectRoot\frontend'; "

    if ($proxyEnabled -and $proxyServer) {
        Write-Host "[提示] 检测到代理配置已启用" -ForegroundColor Yellow
        Write-Host "  代理服务器: $proxyServer" -ForegroundColor White
        Write-Host ""

        # 设置代理环境变量
        $backendCmd += "`$env:HTTP_PROXY='$proxyServer'; `$env:HTTPS_PROXY='$proxyServer'; `$env:ALL_PROXY='$proxyServer'; "
        $frontendCmd += "`$env:HTTP_PROXY='$proxyServer'; `$env:HTTPS_PROXY='$proxyServer'; `$env:ALL_PROXY='$proxyServer'; "
    } else {
        Write-Host "[提示] 代理未启用,使用直连" -ForegroundColor Gray
        Write-Host ""
    }

    # 添加实际启动命令
    $backendCmd += "uv run alembic upgrade head; uv run python app.py"
    $frontendCmd += "npm run dev"

    Write-Host "[1/2] 启动后端服务..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $backendCmd
    Start-Sleep -Seconds 3

    Write-Host ""
    Write-Host "[2/2] 启动前端服务..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $frontendCmd
    Start-Sleep -Seconds 2

    Write-Host ""
    Write-Host "[成功] 服务已启动!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  后端: http://localhost:5000" -ForegroundColor White
    Write-Host "  前端: http://localhost:3000" -ForegroundColor White
    Write-Host ""
    Write-Host "按任意键继续..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Stop-Services {
    Clear-Host
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  停止服务" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "[1/2] 停止后端服务..." -ForegroundColor Yellow
    $backendProcesses = Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*banana-slides*" }
    if ($backendProcesses) {
        $backendProcesses | Stop-Process -Force
        Write-Host "  [成功] 后端服务已停止" -ForegroundColor Green
    } else {
        Write-Host "  [提示] 未找到运行中的后端服务" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "[2/2] 停止前端服务..." -ForegroundColor Yellow
    $frontendProcesses = Get-Process node -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*banana-slides*" }
    if ($frontendProcesses) {
        $frontendProcesses | Stop-Process -Force
        Write-Host "  [成功] 前端服务已停止" -ForegroundColor Green
    } else {
        Write-Host "  [提示] 未找到运行中的前端服务" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "[完成] 服务停止完成" -ForegroundColor Green
    Write-Host ""
    Write-Host "按任意键继续..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Show-Status {
    Clear-Host
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  服务状态" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # 检查后端
    Write-Host "后端服务 (Python):" -ForegroundColor Yellow
    $backendProcesses = Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*banana-slides*" }
    if ($backendProcesses) {
        Write-Host "  [运行中] PID: $($backendProcesses.Id)" -ForegroundColor Green
    } else {
        Write-Host "  [未运行]" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "前端服务 (Node.js):" -ForegroundColor Yellow
    $frontendProcesses = Get-Process node -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*banana-slides*" }
    if ($frontendProcesses) {
        Write-Host "  [运行中] PID: $($frontendProcesses.Id)" -ForegroundColor Green
    } else {
        Write-Host "  [未运行]" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "端口监听状态:" -ForegroundColor Yellow
    $ports = @(5000, 3000)
    foreach ($port in $ports) {
        $connection = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if ($connection) {
            Write-Host "  [监听中] 端口 $port" -ForegroundColor Green
        } else {
            Write-Host "  [未监听] 端口 $port" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "按任意键继续..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Edit-Config {
    Clear-Host
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  配置环境" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Set-Location $projectRoot

    $envFile = ".env"
    $portableEnv = Join-Path $scriptPath ".env.default"

    if (-not (Test-Path $envFile)) {
        Write-Host "[提示] 未找到 .env 文件,正在创建..." -ForegroundColor Yellow

        # 优先使用 portable 目录下的默认配置
        if (Test-Path $portableEnv) {
            Copy-Item $portableEnv $envFile
            Write-Host "  [成功] .env 文件已创建 (使用 portable 默认配置)" -ForegroundColor Green
        } elseif (Test-Path ".env.example") {
            Copy-Item ".env.example" $envFile
            Write-Host "  [成功] .env 文件已创建 (使用 .env.example)" -ForegroundColor Green
        } else {
            Write-Host "  [错误] 未找到配置模板文件!" -ForegroundColor Red
            Write-Host ""
            Write-Host "按任意键继续..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }
        Write-Host ""
    }

    Write-Host "正在打开 .env 文件..." -ForegroundColor Yellow
    notepad $envFile

    Write-Host ""
    Write-Host "[提示] 配置修改后请重启服务生效" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "按任意键继续..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Install-Dependencies {
    Clear-Host
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  安装项目依赖" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Set-Location $projectRoot

    Write-Host "[1/2] 安装后端依赖..." -ForegroundColor Yellow
    Set-Location "backend"
    & uv sync
    Set-Location $projectRoot
    Write-Host ""

    Write-Host "[2/2] 安装前端依赖..." -ForegroundColor Yellow
    Set-Location "frontend"
    & npm install
    Set-Location $projectRoot
    Write-Host ""

    Write-Host "[成功] 依赖安装完成" -ForegroundColor Green
    Write-Host ""
    Write-Host "按任意键继续..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Clean-Data {
    Clear-Host
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  清理项目数据" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[警告] 此操作将删除:" -ForegroundColor Yellow
    Write-Host "  - 数据库文件 (backend/instance/database.db)" -ForegroundColor White
    Write-Host "  - 上传的文件 (uploads/)" -ForegroundColor White
    Write-Host ""

    $confirm = Read-Host "确定要继续吗? (Y=是, N=否)"
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        return
    }

    Set-Location $projectRoot

    Write-Host ""
    Write-Host "[1/2] 清理数据库..." -ForegroundColor Yellow
    $dbPath = "backend\instance\database.db"
    if (Test-Path $dbPath) {
        Remove-Item $dbPath -Force
        Write-Host "  [成功] 数据库已清理" -ForegroundColor Green
    } else {
        Write-Host "  [提示] 数据库不存在" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "[2/2] 清理上传文件..." -ForegroundColor Yellow
    $uploadsPath = "uploads"
    if (Test-Path $uploadsPath) {
        Remove-Item $uploadsPath -Recurse -Force
        New-Item -ItemType Directory -Path $uploadsPath | Out-Null
        Write-Host "  [成功] 上传文件已清理" -ForegroundColor Green
    } else {
        Write-Host "  [提示] 上传目录不存在" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "[完成] 数据清理完成" -ForegroundColor Green
    Write-Host ""
    Write-Host "按任意键继续..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Configure-Proxy {
    Clear-Host
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  配置代理" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Set-Location $projectRoot

    $proxyFile = ".proxy"
    $defaultProxyFile = Join-Path $scriptPath ".proxy.default"

    # 如果代理配置文件不存在，从默认配置创建
    if (-not (Test-Path $proxyFile)) {
        Write-Host "[提示] 未找到 .proxy 文件，正在创建..." -ForegroundColor Yellow
        if (Test-Path $defaultProxyFile) {
            Copy-Item $defaultProxyFile $proxyFile
            Write-Host "  [成功] .proxy 文件已创建" -ForegroundColor Green
        } else {
            Write-Host "  [错误] 未找到默认代理配置文件!" -ForegroundColor Red
            Write-Host ""
            Write-Host "按任意键继续..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }
        Write-Host ""
    }

    # 读取当前配置
    $proxyEnabled = $false
    $proxyServer = ""

    if (Test-Path $proxyFile) {
        $content = Get-Content $proxyFile -Raw
        if ($content -match 'PROXY_ENABLED=true') {
            $proxyEnabled = $true
        }
        if ($content -match 'PROXY_SERVER=(.+)') {
            $proxyServer = $matches[1].Trim()
        }
    }

    # 显示当前配置
    Write-Host "当前代理配置:" -ForegroundColor Yellow
    Write-Host "  状态: $(if ($proxyEnabled) { '[已启用]' } else { '[已禁用]' })" -ForegroundColor $(if ($proxyEnabled) { 'Green' } else { 'Red' })
    if ($proxyServer) {
        Write-Host "  服务器: $proxyServer" -ForegroundColor White
    }
    Write-Host ""

    # 配置菜单
    Write-Host "请选择操作:" -ForegroundColor White
    Write-Host ""
    Write-Host "  [1] 启用代理" -ForegroundColor White
    Write-Host "  [2] 禁用代理" -ForegroundColor White
    Write-Host "  [3] 修改代理服务器地址" -ForegroundColor White
    Write-Host "  [4] 使用默认代理 (socks5://socks.spdt.work:63000)" -ForegroundColor White
    Write-Host "  [5] 编辑配置文件" -ForegroundColor White
    Write-Host "  [0] 返回主菜单" -ForegroundColor White
    Write-Host ""

    $choice = Read-Host "请输入选项 (0-5)"

    switch ($choice) {
        "1" {
            (Get-Content $proxyFile) -replace 'PROXY_ENABLED=false', 'PROXY_ENABLED=true' | Set-Content $proxyFile
            Write-Host ""
            Write-Host "[成功] 代理已启用" -ForegroundColor Green
            Write-Host ""
            Write-Host "[提示] 重新启动服务后生效" -ForegroundColor Yellow
        }
        "2" {
            (Get-Content $proxyFile) -replace 'PROXY_ENABLED=true', 'PROXY_ENABLED=false' | Set-Content $proxyFile
            Write-Host ""
            Write-Host "[成功] 代理已禁用" -ForegroundColor Green
        }
        "3" {
            Write-Host ""
            $newServer = Read-Host "请输入代理服务器地址 (例如: socks://127.0.0.1:1080)"
            if ($newServer) {
                (Get-Content $proxyFile) -replace 'PROXY_SERVER=.+', "PROXY_SERVER=$newServer" | Set-Content $proxyFile
                Write-Host ""
                Write-Host "[成功] 代理服务器地址已更新为: $newServer" -ForegroundColor Green
                Write-Host ""
                Write-Host "[提示] 重新启动服务后生效" -ForegroundColor Yellow
            }
        }
        "4" {
            (Get-Content $proxyFile) -replace 'PROXY_SERVER=.+', 'PROXY_SERVER=socks5://socks.spdt.work:63000' | Set-Content $proxyFile
            (Get-Content $proxyFile) -replace 'PROXY_ENABLED=false', 'PROXY_ENABLED=true' | Set-Content $proxyFile
            Write-Host ""
            Write-Host "[成功] 已设置为默认代理并启用" -ForegroundColor Green
            Write-Host ""
            Write-Host "[提示] 重新启动服务后生效" -ForegroundColor Yellow
        }
        "5" {
            Write-Host ""
            Write-Host "正在打开 .proxy 文件..." -ForegroundColor Yellow
            notepad $proxyFile
            Write-Host ""
            Write-Host "[提示] 配置修改后请重启服务生效" -ForegroundColor Yellow
        }
        "0" {
            return
        }
        default {
            Write-Host ""
            Write-Host "[错误] 无效的选项" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "按任意键继续..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Update-AllCode {
    Clear-Host
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  更新所有代码" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Set-Location $projectRoot

    # 检查是否有Git仓库
    if (-not (Test-Path ".git")) {
        Write-Host "[错误] 当前目录不是Git仓库!" -ForegroundColor Red
        Write-Host ""
        Write-Host "便携版不支持自动更新,请手动下载最新版本" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "下载地址: https://github.com/Anionex/banana-slides" -ForegroundColor White
        Write-Host ""
        Write-Host "按任意键继续..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    # 检查是否有未提交的更改
    Write-Host "[1/4] 检查本地更改..." -ForegroundColor Yellow
    $gitStatus = git status --porcelain
    if ($gitStatus) {
        Write-Host "  [警告] 检测到未提交的更改:" -ForegroundColor Yellow
        git status --short
        Write-Host ""
        $confirm = Read-Host "是否继续更新? 未提交的更改可能会丢失 (Y=是, N=否)"
        if ($confirm -ne "Y" -and $confirm -ne "y") {
            Write-Host ""
            Write-Host "[已取消] 更新操作已取消" -ForegroundColor Gray
            Write-Host ""
            Write-Host "按任意键继续..." -ForegroundColor Gray
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }
        Write-Host ""
        Write-Host "  [提示] 将暂存本地更改..." -ForegroundColor Yellow
        git stash
    } else {
        Write-Host "  [成功] 工作区干净" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "[2/4] 从远程拉取最新代码..." -ForegroundColor Yellow
    git pull

    Write-Host ""
    Write-Host "[3/4] 检查更新结果..." -ForegroundColor Yellow
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [错误] 代码更新失败" -ForegroundColor Red
        Write-Host ""
        Write-Host "按任意键继续..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    Write-Host "  [成功] 代码已更新到最新版本" -ForegroundColor Green

    # 如果之前有stash,询问是否恢复
    if ($gitStatus) {
        Write-Host ""
        $restoreStash = Read-Host "是否恢复之前暂存的更改? (Y=是, N=否)"
        if ($restoreStash -eq "Y" -or $restoreStash -eq "y") {
            Write-Host ""
            Write-Host "[4/4] 恢复暂存的更改..." -ForegroundColor Yellow
            git stash pop
        } else {
            Write-Host ""
            Write-Host "[提示] 暂存的更改保留在 stash 中,可使用 'git stash pop' 恢复" -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Host "[完成] 代码更新完成!" -ForegroundColor Green
    Write-Host ""
    Write-Host "[建议] 更新后请执行以下操作:" -ForegroundColor Yellow
    Write-Host "  1. 选择菜单 [6] 安装依赖" -ForegroundColor White
    Write-Host "  2. 选择菜单 [3] 重启服务" -ForegroundColor White
    Write-Host ""
    Write-Host "按任意键继续..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# 主循环
while ($true) {
    Show-Menu

    $choice = Read-Host "请输入选项 (0-9)"

    switch ($choice) {
        "1" {
            Start-Services
        }
        "2" {
            Stop-Services
        }
        "3" {
            Stop-Services
            Start-Sleep -Seconds 2
            Start-Services
        }
        "4" {
            Show-Status
        }
        "5" {
            Edit-Config
        }
        "6" {
            Install-Dependencies
        }
        "7" {
            Clean-Data
        }
        "8" {
            Start-Process "http://localhost:3000"
            Write-Host ""
            Write-Host "[成功] 已打开浏览器" -ForegroundColor Green
            Start-Sleep -Seconds 2
        }
        "9" {
            Update-AllCode
        }
        "P" {
            Configure-Proxy
        }
        "p" {
            Configure-Proxy
        }
        "0" {
            Clear-Host
            Write-Host ""
            Write-Host "感谢使用 Banana Slides!" -ForegroundColor Cyan
            Write-Host ""
            Start-Sleep -Seconds 2
            exit
        }
        default {
            Write-Host ""
            Write-Host "[错误] 无效的选项" -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}
