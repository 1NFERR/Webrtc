#!/usr/bin/env bash
# Usage:
#   ./start.sh          # dev mode (default)
#   ./start.sh --prod   # prod mode

set -euo pipefail

MODE="dev"
if [[ "${1:-}" == "--prod" ]]; then
  MODE="prod"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "=== WebRTC Car Video Prototype ==="
echo "Mode: $MODE"
echo ""

# ---------------------------------------------------------------------------
# Check dependencies
# ---------------------------------------------------------------------------
echo "Checking dependencies..."
command -v node    &>/dev/null || { echo "  ERROR: node is not installed";   exit 1; }
command -v npm     &>/dev/null || { echo "  ERROR: npm is not installed";    exit 1; }
command -v python3 &>/dev/null || { echo "  ERROR: python3 is not installed"; exit 1; }
echo "  node $(node --version), npm $(npm --version), python3 $(python3 --version)"
echo ""

# ---------------------------------------------------------------------------
# .env: copy from .env.example if missing
# ---------------------------------------------------------------------------
ensure_env() {
  local dir="$1"
  local env_file="$dir/.env"
  local example_file="$dir/.env.example"
  if [[ ! -f "$env_file" ]]; then
    if [[ -f "$example_file" ]]; then
      cp "$example_file" "$env_file"
      echo "  [.env] Created $env_file from .env.example — please check variables"
    else
      echo "  [.env] WARNING: no .env and no .env.example found in $dir"
    fi
  else
    echo "  [.env] $env_file already exists, skipping"
  fi
}

echo "Checking .env files..."
ensure_env "$REPO_ROOT/signaling-server"
ensure_env "$REPO_ROOT/frontend"
ensure_env "$REPO_ROOT/car-video-client"
echo ""

# ---------------------------------------------------------------------------
# Install dependencies
# ---------------------------------------------------------------------------
echo "Installing dependencies..."

if [[ -d "$REPO_ROOT/signaling-server/node_modules" ]]; then
  echo "  [signaling-server] node_modules already exists, skipping"
else
  echo "  [signaling-server] Running npm install..."
  (cd "$REPO_ROOT/signaling-server" && npm install --silent)
  echo "  [signaling-server] Done"
fi

if [[ -d "$REPO_ROOT/frontend/node_modules" ]]; then
  echo "  [frontend] node_modules already exists, skipping"
else
  echo "  [frontend] Running npm install..."
  (cd "$REPO_ROOT/frontend" && npm install --silent)
  echo "  [frontend] Done"
fi

VENV="$REPO_ROOT/car-video-client/.venv"
if [[ -d "$VENV" ]]; then
  echo "  [car-video-client] .venv already exists, skipping venv creation"
else
  echo "  [car-video-client] Creating virtual environment..."
  python3 -m venv "$VENV"
fi
echo "  [car-video-client] Installing Python packages..."
"$VENV/bin/pip" install --quiet -r "$REPO_ROOT/car-video-client/requirements.txt"
echo "  [car-video-client] Done"

echo ""

# ---------------------------------------------------------------------------
# Build commands
# ---------------------------------------------------------------------------
if [[ "$MODE" == "dev" ]]; then
  CMD_SIGNAL="cd '$REPO_ROOT/signaling-server' && npm run dev"
  CMD_FRONT="cd '$REPO_ROOT/frontend' && npm run dev"
else
  CMD_SIGNAL="cd '$REPO_ROOT/signaling-server' && npm start"
  CMD_FRONT="cd '$REPO_ROOT/frontend' && npm run build && npm run preview"
fi
CMD_CAR="cd '$REPO_ROOT/car-video-client' && source .venv/bin/activate && python main.py"

# ---------------------------------------------------------------------------
# Open terminals (macOS / Linux)
# ---------------------------------------------------------------------------
open_terminal() {
  local title="$1"
  local cmd="$2"

  if [[ "$(uname -s)" == "Darwin" ]]; then
    osascript -e "tell application \"Terminal\" to do script \"$cmd\""
  elif command -v gnome-terminal &>/dev/null; then
    gnome-terminal --title="$title" -- bash -c "$cmd; exec bash"
  elif command -v xterm &>/dev/null; then
    xterm -title "$title" -e bash -c "$cmd; exec bash" &
  else
    echo "  WARNING: no supported terminal found. Run manually: $cmd"
  fi
}

echo "Starting components..."
open_terminal "signaling-server"  "$CMD_SIGNAL"
echo "  [signaling-server] Terminal opened"
open_terminal "frontend"          "$CMD_FRONT"
echo "  [frontend] Terminal opened"
open_terminal "car-video-client"  "$CMD_CAR"
echo "  [car-video-client] Terminal opened"

echo ""
echo "All components started (mode: $MODE)"
echo "  Signaling server: http://localhost:4000"
echo "  Frontend:         http://localhost:5173"
echo ""