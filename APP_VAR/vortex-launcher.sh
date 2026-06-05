#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAUNCHER_DIR="$SCRIPT_DIR/vortex-launcher"

export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
fi

ELECTRON="$LAUNCHER_DIR/node_modules/.bin/electron"
if [ ! -x "$ELECTRON" ]; then
    echo "==> Electron not found, running npm install..."
    npm --prefix "$LAUNCHER_DIR" install
fi

echo "==> Starting Vortex Launcher..."
exec "$ELECTRON" "$LAUNCHER_DIR" "$@"
