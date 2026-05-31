param(
    [string]$PythonVersion = "3.12",
    [string]$HostName = "0.0.0.0",
    [int]$Port = 8000,
    [switch]$SkipBrowsers,
    [switch]$SkipFrontend,
    [switch]$NoStart
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function Write-Step {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing command '$Name'. Install it and make sure it is available in PATH."
    }
}

function Invoke-Step {
    param(
        [string]$Message,
        [scriptblock]$Command
    )
    Write-Step $Message
    & $Command
    Write-Ok $Message
}

function Install-CamoufoxFromGitHubRelease {
    Require-Command "gh"

    $tag = "v135.0.1-beta.24"
    $asset = "camoufox-135.0.1-beta.24-win.x86_64.zip"
    $downloadDir = Join-Path $Root ".codex-review\camoufox-download"
    $zipPath = Join-Path $downloadDir $asset
    $cacheDir = Join-Path $env:LOCALAPPDATA "camoufox\camoufox\Cache"

    New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null
    gh release download $tag --repo "daijro/camoufox" --pattern $asset --dir $downloadDir --clobber

    if (Test-Path $cacheDir) {
        Remove-Item -LiteralPath $cacheDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
    Expand-Archive -Path $zipPath -DestinationPath $cacheDir -Force

    $versionPath = Join-Path $cacheDir "version.json"
    $versionJson = '{"version":"135.0.1","release":"beta.24"}'
    [System.IO.File]::WriteAllText($versionPath, $versionJson, (New-Object System.Text.UTF8Encoding($false)))
}

if (-not (Test-Path "main.py") -or -not (Test-Path "requirements.txt")) {
    throw "Run this script from the project root, or keep deploy.ps1 in the project root."
}

Require-Command "uv"
if (-not $SkipFrontend) {
    Require-Command "pnpm"
}

if (Test-Path ".venv\pyvenv.cfg") {
    Write-Ok "Python virtual environment already exists"
}
else {
    Invoke-Step "Creating Python virtual environment with uv" {
        uv venv --python $PythonVersion
    }
}

Invoke-Step "Installing Python dependencies" {
    uv pip install -r requirements.txt
}

if (-not $SkipBrowsers) {
    Invoke-Step "Installing Playwright Chromium" {
        uv run python -m playwright install chromium
    }

    Write-Step "Installing Camoufox browser runtime"
    try {
        uv run python -m camoufox fetch
        Write-Ok "Installing Camoufox browser runtime"
    }
    catch {
        Write-Warn "Camoufox fetch failed. Trying authenticated GitHub CLI release download fallback."
        Install-CamoufoxFromGitHubRelease
        uv run python -c "from camoufox.pkgman import launch_path, installed_verstr; print(installed_verstr()); print(launch_path())"
        Write-Ok "Installed Camoufox browser runtime from GitHub release asset"
    }
}

if (-not (Test-Path ".env")) {
    if (Test-Path ".env.example") {
        Copy-Item ".env.example" ".env"
        Write-Warn "Created .env from .env.example. Review it before using production credentials."
    }
    else {
        @"
HOST=0.0.0.0
PORT=8000
APP_RELOAD=0
APP_CONDA_ENV=
"@ | Set-Content -Encoding utf8 ".env"
        Write-Warn "Created a minimal .env. Review it before using production credentials."
    }
}
else {
    Write-Ok ".env already exists"
}

if (-not $SkipFrontend -and (Test-Path "frontend\package.json")) {
    Push-Location "frontend"
    try {
        Invoke-Step "Installing frontend dependencies with pnpm" {
            pnpm install
        }
        Invoke-Step "Building frontend with pnpm" {
            pnpm run build
        }
    }
    finally {
        Pop-Location
    }
}
elseif ($SkipFrontend) {
    Write-Warn "Skipping frontend install/build"
}
else {
    Write-Warn "No frontend/package.json found; skipping frontend install/build"
}

Write-Ok "Deployment steps completed"

if (-not $NoStart) {
    $env:HOST = $HostName
    $env:PORT = [string]$Port
    $env:APP_CONDA_ENV = ""
    $displayHost = if ($HostName -eq "0.0.0.0") { "localhost" } else { $HostName }
    Write-Step "Starting backend at http://$displayHost`:$Port"
    uv run python main.py
}
else {
    Write-Step "Start later with: uv run python main.py"
}
