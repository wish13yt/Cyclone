# Vortex Launcher

Electron desktop app that wraps `playvortex.io` in an embedded webview with saved-account login and game-client launching.

## Setup

```bash
# From the Vortex project root:
./setup.sh
```

Or manually:

```bash
cd APP_VAR/vortex-launcher
npm install
```

## Usage

```bash
./APP_VAR/vortex-launcher.sh
```

Or launch from your application menu ("Vortex Launcher").

## Features

- **Webview** — embedded `playvortex.io` with back/forward/refresh navigation and editable URL bar
- **Account management** — reads saved credentials from `config/usernamesandpasswords`, auto-logs out before switching users
- **Game launcher** — three modes:
  - `wine` — Vortex.exe via Wine
  - `native` — vortex-studio Linux binary
  - `receiver` — receiver.exe API daemon (Wine)
- **Process lifecycle** — start/kill game processes, exit detection

## Keyboard Shortcuts

| Key | Action |
|---|---|
| `Ctrl+L` | Focus URL bar |
| `Escape` | Close side panel |
| `Enter` (URL bar) | Navigate to URL |
| `Enter` (login form) | Submit login |
