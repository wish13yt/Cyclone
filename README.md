# Cyclone

Vortex web app launcher — Electron wrapper for playvortex.io with saved-account login and game-client launching.

## Setup

```bash
# Download install-vortex.sh from the latest release:
# https://github.com/liderazgoreborn5-gif/Cyclone/releases

chmod +x install-vortex.sh
./install-vortex.sh
```

The script downloads Vortex, installs Wine dependencies, deploys the web launcher, and creates desktop shortcuts.

## What's in the repo

- `APP_VAR/` — Electron launcher app (main.js, renderer, preload)

The `install-vortex.sh` setup script lives only in [releases](https://github.com/liderazgoreborn5-gif/Cyclone/releases).
