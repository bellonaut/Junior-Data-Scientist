#requires -Version 5.0
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

function Log([string]$msg) { Write-Host "[ui-demo] $msg" -ForegroundColor Green }
function Warn([string]$msg) { Write-Host "[warn] $msg" -ForegroundColor Yellow }
function Fail([string]$msg) { Write-Host "[fail] $msg" -ForegroundColor Red; exit 1 }

function NeedCmd([string]$cmd) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Fail "Missing required command: $cmd"
    }
}

NeedCmd python

$venv = ".venv-demo"
$venvPython = Join-Path $venv "Scripts\python.exe"
$reqFile = "requirements-ui-demo.txt"
$pidFile = ".ui-demo.pid"
$apiPort = if ($env:API_PORT) { $env:API_PORT } else { 8000 }

if (-not (Test-Path $reqFile)) { Fail "Missing $reqFile; run from repo root." }

if (-not (Test-Path $venvPython)) {
    Log "Creating virtualenv at $venv"
    python -m venv $venv
}

Log "Installing UI demo dependencies..."
& $venvPython -m pip install --quiet --upgrade pip
& $venvPython -m pip install --quiet -r $reqFile

if (-not $env:DB_URL) { $env:DB_URL = "sqlite:///./demo.db" }
if (-not $env:ENV) { $env:ENV = "demo" }
if (-not $env:DAGSTER_GRAPHQL_URL) { $env:DAGSTER_GRAPHQL_URL = "http://localhost:3000/graphql" }

Log "Using DB_URL=$env:DB_URL (SQLite demo)"

Log "Applying migrations..."
& $venvPython -m alembic upgrade head

Log "Seeding synthetic demo data..."
& $venvPython scripts/seed_demo.py --db-url $env:DB_URL --force | Out-Null

if (Test-Path $pidFile) {
    $oldPid = Get-Content $pidFile
    try {
        Stop-Process -Id $oldPid -ErrorAction SilentlyContinue
        Warn "Stopping previous UI demo server (pid $oldPid)"
    } catch {}
    Remove-Item $pidFile -ErrorAction SilentlyContinue
}

Log "Starting FastAPI UI demo on port $apiPort..."
$uvicornArgs = "-m","uvicorn","carms.api.main:app","--host","0.0.0.0","--port",$apiPort,"--log-level","warning"
$uvicornProc = Start-Process -FilePath $venvPython -ArgumentList $uvicornArgs -PassThru -WindowStyle Minimized
Set-Content -Path $pidFile -Value $uvicornProc.Id

Log "Waiting for API health..."
& $venvPython scripts/wait_for_http.py "http://localhost:$apiPort/health" 60 | Out-Null

Log "Opening key pages (best-effort)..."
Start-Process "http://localhost:$apiPort/docs" | Out-Null
Start-Process "http://localhost:$apiPort/map" | Out-Null

Log "UI demo is running. Quick links:"
Write-Host "Docs:         http://localhost:$apiPort/docs"
Write-Host "Program list: http://localhost:$apiPort/programs?province=ON&limit=5&include_total=true"
Write-Host "Map:          http://localhost:$apiPort/map"
Write-Host "Note: UI demo uses seeded synthetic data; full demo runs the Dagster pipeline." -ForegroundColor Yellow
Write-Host "To stop: Stop-Process -Id $(Get-Content $pidFile)" -ForegroundColor Yellow
