# Cyclone
An official Linux build of Vortex is being released soon (apparently)! My fork only patches the script to use the new download URL.
## Setup

```bash
# Download install-vortex.sh from the latest release:
# https://github.com/wish13yt/Cyclone/releases

chmod +x install-vortex.sh
./install-vortex.sh
```

The script downloads Vortex, installs Wine dependencies, deploys the web launcher, and creates desktop shortcuts.

## What's in the repo

- `APP_VAR/` - Electron launcher app (main.js, renderer, preload)
- `install-vortex.sh` - Vortex installer script
