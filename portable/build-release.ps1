# Banana Slides - Release Packaging Script
# Creates portable ZIP package

param(
    [string]$Version = "",
    [switch]$SkipCleanCheck = $false
)

# Set encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Get script directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Join-Path $scriptPath ".."

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Banana Slides Portable Packaging Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Switch to project root
Set-Location $projectRoot

# 1. Check Git workspace status
Write-Host "[1/6] Checking Git workspace status..." -ForegroundColor Yellow
if (-not $SkipCleanCheck) {
    $gitStatus = git status --porcelain
    if ($gitStatus) {
        Write-Host "  [Warning] Uncommitted changes detected:" -ForegroundColor Yellow
        git status --short
        Write-Host ""
        $continue = Read-Host "Continue packaging? (Y=Yes, N=No)"
        if ($continue -ne "Y" -and $continue -ne "y") {
            Write-Host ""
            Write-Host "[Cancelled] Packaging cancelled" -ForegroundColor Gray
            exit 1
        }
    } else {
        Write-Host "  [OK] Workspace clean" -ForegroundColor Green
    }
} else {
    Write-Host "  [Skipped] Workspace check skipped" -ForegroundColor Gray
}

# 2. Get version info
Write-Host ""
Write-Host "[2/6] Getting version info..." -ForegroundColor Yellow

# Read version from package.json
$packageJsonPath = Join-Path $projectRoot "frontend\package.json"
if (Test-Path $packageJsonPath) {
    $packageJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
    $defaultVersion = $packageJson.version
} else {
    $defaultVersion = "0.3.0"
}

# Use default version if not specified
if (-not $Version) {
    $Version = $defaultVersion
}

# Get Git branch and commit info
$gitBranch = git rev-parse --abbrev-ref HEAD 2>$null
$gitCommit = git rev-parse --short HEAD 2>$null

Write-Host "  Version: $Version" -ForegroundColor White
Write-Host "  Git Branch: $gitBranch" -ForegroundColor White
Write-Host "  Git Commit: $gitCommit" -ForegroundColor White

# 3. Create temporary directory
Write-Host ""
Write-Host "[3/6] Preparing temporary directory..." -ForegroundColor Yellow

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$tempDir = Join-Path $projectRoot "temp_release_$timestamp"
$outputDir = Join-Path $projectRoot "releases"

# Create output directory
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

# Clean old temporary directories
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}

New-Item -ItemType Directory -Path $tempDir | Out-Null
Write-Host "  Temp directory: $tempDir" -ForegroundColor White

# 4. Export Git files (from origin/main)
Write-Host ""
Write-Host "[4/6] Exporting project files..." -ForegroundColor Yellow

# Use git archive to export clean code
$archivePath = Join-Path $tempDir "archive.zip"
try {
    # Try exporting from origin/main
    git archive --format=zip --output="$archivePath" origin/main 2>$null
    if ($LASTEXITCODE -ne 0) {
        # If origin/main doesn't exist, use current HEAD
        Write-Host "  [Info] origin/main not found, using current HEAD" -ForegroundColor Gray
        git archive --format=zip --output="$archivePath" HEAD
    }
} catch {
    Write-Host "  [Error] Git archive failed: $_" -ForegroundColor Red
    exit 1
}

# Extract to temp directory
Expand-Archive -Path $archivePath -DestinationPath $tempDir -Force
Remove-Item $archivePath -Force

Write-Host "  [OK] Project files exported" -ForegroundColor Green

# 5. Add portable directory
Write-Host ""
Write-Host "[5/6] Adding portable directory..." -ForegroundColor Yellow

$portableSource = Join-Path $projectRoot "portable"
$portableDest = Join-Path $tempDir "portable"

if (Test-Path $portableSource) {
    # Copy portable directory, exclude packaging script itself
    Copy-Item -Path $portableSource -Destination $portableDest -Recurse -Force

    # Delete unnecessary files
    $excludeFiles = @(
        "build-release.ps1",  # Packaging script itself
        "*.zip"               # Old zip packages
    )

    foreach ($pattern in $excludeFiles) {
        Get-ChildItem -Path $portableDest -Filter $pattern -Recurse | Remove-Item -Force
    }

    Write-Host "  [OK] portable directory added" -ForegroundColor Green
} else {
    Write-Host "  [Warning] portable directory not found" -ForegroundColor Yellow
}

# Clean unnecessary files and directories
Write-Host "  Cleaning unnecessary files..." -ForegroundColor Gray

$cleanupItems = @(
    ".venv",
    ".git",
    ".github",
    ".githooks",
    "node_modules",
    "dist",
    "build",
    "__pycache__",
    "*.pyc",
    ".pytest_cache",
    ".coverage",
    "htmlcov",
    "instance",
    "uploads",
    ".env",
    "temp_*",
    "releases",
    "*.log",
    ".spec-workflow"
)

foreach ($item in $cleanupItems) {
    Get-ChildItem -Path $tempDir -Filter $item -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
}

# 6. Create ZIP package
Write-Host ""
Write-Host "[6/6] Creating ZIP package..." -ForegroundColor Yellow

$zipFileName = "banana-slides-portable-v$Version.zip"
$zipPath = Join-Path $outputDir $zipFileName

if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

# Use .NET compression (cross-platform compatible)
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)

# Clean temp directory
Remove-Item $tempDir -Recurse -Force

# Get file size
$zipSize = (Get-Item $zipPath).Length
$zipSizeMB = [math]::Round($zipSize / 1MB, 2)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Packaging Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  File: $zipFileName" -ForegroundColor White
Write-Host "  Path: $zipPath" -ForegroundColor White
Write-Host "  Size: $zipSizeMB MB" -ForegroundColor White
Write-Host ""
Write-Host "  Version Info:" -ForegroundColor Yellow
Write-Host "    - Version: $Version" -ForegroundColor White
Write-Host "    - Git Branch: $gitBranch" -ForegroundColor White
Write-Host "    - Git Commit: $gitCommit" -ForegroundColor White
Write-Host ""
Write-Host "  Usage:" -ForegroundColor Yellow
Write-Host "    1. Extract ZIP to any directory" -ForegroundColor White
Write-Host "    2. Run portable\OneClickStart.bat" -ForegroundColor White
Write-Host "    3. Follow prompts to install Node.js and uv" -ForegroundColor White
Write-Host "    4. Script will auto-create Python venv and start services" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
