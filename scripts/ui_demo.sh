#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

log() { printf "\033[1;32m[ui-demo]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }
fail() { printf "\033[1;31m[fail]\033[0m %s\n" "$*"; exit 1; }

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

open_url() {
    local url="$1"
    if command -v open >/dev/null 2>&1; then
        open "$url" >/dev/null 2>&1 || true
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$url" >/dev/null 2>&1 || true
    else
        warn "Open your browser to: $url"
    fi
}

need_cmd python

VENV=".venv-demo"
REQ_FILE="requirements-ui-demo.txt"
PID_FILE=".ui-demo.pid"
API_PORT="${API_PORT:-8000}"
DB_URL="${DB_URL:-sqlite:///./demo.db}"
ENV="${ENV:-demo}"
PYTHONPATH="${PYTHONPATH:-}"

[ -f "$REQ_FILE" ] || fail "Missing $REQ_FILE; run from repo root."

if [ ! -d "$VENV" ]; then
    log "Creating virtualenv at $VENV"
    python -m venv "$VENV"
fi
# shellcheck disable=SC1090
source "$VENV/bin/activate"

log "Installing UI demo dependencies..."
python -m pip install --quiet --upgrade pip
python -m pip install --quiet -r "$REQ_FILE"

export PYTHONPATH="${ROOT_DIR}${PYTHONPATH:+:$PYTHONPATH}"
export DB_URL ENV
log "Using DB_URL=$DB_URL (SQLite demo)"

log "Applying migrations..."
alembic upgrade head

log "Seeding synthetic demo data..."
python scripts/seed_demo.py --db-url "$DB_URL" --force

if [ -f "$PID_FILE" ]; then
    old_pid=$(cat "$PID_FILE")
    if kill -0 "$old_pid" 2>/dev/null; then
        warn "Stopping previous UI demo server (pid $old_pid)"
        kill "$old_pid" || true
    fi
    rm -f "$PID_FILE"
fi

log "Starting FastAPI UI demo on port $API_PORT..."
nohup env DB_URL="$DB_URL" ENV="$ENV" \
    uvicorn carms.api.main:app --host 0.0.0.0 --port "$API_PORT" --log-level warning \
    > .ui-demo-api.log 2>&1 &
echo $! > "$PID_FILE"

python scripts/wait_for_http.py "http://localhost:${API_PORT}/health" 60

log "Opening key pages (best-effort)..."
open_url "http://localhost:${API_PORT}/docs"
open_url "http://localhost:${API_PORT}/map"

log "UI demo is running. Quick links:"
log "Docs:         http://localhost:${API_PORT}/docs"
log "Program list: http://localhost:${API_PORT}/programs?province=ON&limit=5&include_total=true"
log "Map:          http://localhost:${API_PORT}/map"
log "Note: UI demo uses seeded synthetic data; full demo runs the Dagster pipeline."
log "To stop: kill $(cat $PID_FILE) && rm $PID_FILE"
