# Usage:
#   .\start.ps1          # dev mode (default)
#   .\start.ps1 --prod   # prod mode

param(
    [switch]$prod
)

$Mode = if ($prod) { "prod" } else { "dev" }
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "=== WebRTC Car Video Prototype ==="
Write-Host "Mode: $Mode"
Write-Host ""

# ---------------------------------------------------------------------------
# Check dependencies
# ---------------------------------------------------------------------------
Write-Host "Checking dependencies..."
foreach ($cmd in @("node", "npm", "python")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "$cmd is not installed"
        exit 1
    }
}
Write-Host "  node $(node --version), npm $(npm --version), python $(python --version)"
Write-Host ""

# ---------------------------------------------------------------------------
# .env: copy from .env.example if missing
# ---------------------------------------------------------------------------
function Ensure-Env {
    param($dir)
    $envFile     = Join-Path $dir ".env"
    $exampleFile = Join-Path $dir ".env.example"
    if (-not (Test-Path $envFile)) {
        if (Test-Path $exampleFile) {
            Copy-Item $exampleFile $envFile
            Write-Host "  [.env] Created $envFile from .env.example — please check variables"
        } else {
            Write-Host "  [.env] WARNING: no .env and no .env.example found in $dir"
        }
    } else {
        Write-Host "  [.env] $envFile already exists, skipping"
    }
}

Write-Host "Checking .env files..."
Ensure-Env (Join-Path $RepoRoot "signaling-server")
Ensure-Env (Join-Path $RepoRoot "frontend")
Ensure-Env (Join-Path $RepoRoot "car-video-client")
Write-Host ""

# ---------------------------------------------------------------------------
# Install dependencies
# ---------------------------------------------------------------------------
Write-Host "Installing dependencies..."

$nodeModulesSignal = Join-Path $RepoRoot "signaling-server\node_modules"
if (Test-Path $nodeModulesSignal) {
    Write-Host "  [signaling-server] node_modules already exists, skipping"
} else {
    Write-Host "  [signaling-server] Running npm install..."
    Push-Location (Join-Path $RepoRoot "signaling-server")
    npm install --silent
    Pop-Location
    Write-Host "  [signaling-server] Done"
}

$nodeModulesFront = Join-Path $RepoRoot "frontend\node_modules"
if (Test-Path $nodeModulesFront) {
    Write-Host "  [frontend] node_modules already exists, skipping"
} else {
    Write-Host "  [frontend] Running npm install..."
    Push-Location (Join-Path $RepoRoot "frontend")
    npm install --silent
    Pop-Location
    Write-Host "  [frontend] Done"
}

$venv = Join-Path $RepoRoot "car-video-client\.venv"
if (Test-Path $venv) {
    Write-Host "  [car-video-client] .venv already exists, skipping venv creation"
} else {
    Write-Host "  [car-video-client] Creating virtual environment..."
    python -m venv $venv
}
Write-Host "  [car-video-client] Installing Python packages..."
& (Join-Path $venv "Scripts\pip.exe") install --quiet -r (Join-Path $RepoRoot "car-video-client\requirements.txt")
Write-Host "  [car-video-client] Done"

Write-Host ""

# ---------------------------------------------------------------------------
# Build commands
# ---------------------------------------------------------------------------
if ($Mode -eq "dev") {
    $cmdSignal = "Set-Location '$RepoRoot\signaling-server'; npm run dev"
    $cmdFront  = "Set-Location '$RepoRoot\frontend'; npm run dev"
} else {
    $cmdSignal = "Set-Location '$RepoRoot\signaling-server'; npm start"
    $cmdFront  = "Set-Location '$RepoRoot\frontend'; npm run build; npm run preview"
}
$cmdCar = "Set-Location '$RepoRoot\car-video-client'; .\.venv\Scripts\Activate.ps1; python main.py"

# ---------------------------------------------------------------------------
# Open terminals
# ---------------------------------------------------------------------------
function Open-Terminal {
    param($cmd)
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $cmd
}

Write-Host "Starting components..."
Open-Terminal $cmdSignal
Write-Host "  [signaling-server] Terminal opened"
Open-Terminal $cmdFront
Write-Host "  [frontend] Terminal opened"
Open-Terminal $cmdCar
Write-Host "  [car-video-client] Terminal opened"

Write-Host ""
Write-Host "All components started (mode: $Mode)"
Write-Host "  Signaling server: http://localhost:4000"
Write-Host "  Frontend:         http://localhost:5173"
Write-Host ""