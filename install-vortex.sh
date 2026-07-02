#!/bin/bash
set -euo pipefail
# this script is owned by Your Average Mentally Ill Loser, have problems? Dm me!
REPO_URL="https://github.com/HansKristian-Work/vkd3d-proton"
VORTEX_DL="https://vortex.towerstats.com/download/windows"

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }
warn() { echo "WARN: $*" >&2; }

# --- distro detection ---
detect_distro() {
    if   [ -f /etc/os-release ]; then . /etc/os-release; echo "$ID"
    elif command -v lsb_release >/dev/null 2>&1; then lsb_release -si | tr '[:upper:]' '[:lower:]'
    elif [ -f /etc/arch-release  ]; then echo "arch"
    elif [ -f /etc/debian_version ]; then echo "debian"
    elif [ -f /etc/fedora-release ]; then echo "fedora"
    else echo "unknown"
    fi
}

PKG_MANAGER=""
PKG_INSTALL=""
PKG_UPDATE=""
DISTRO=$(detect_distro)

case "$DISTRO" in
    debian|ubuntu|pop|linuxmint|elementary|zorin)
        PKG_MANAGER="apt-get"
        PKG_UPDATE="$PKG_MANAGER update"
        PKG_INSTALL="$PKG_MANAGER install -y"
        ;;
    fedora)
        PKG_MANAGER="dnf"
        PKG_UPDATE="$PKG_MANAGER check-update || true"
        PKG_INSTALL="$PKG_MANAGER install -y"
        ;;
    arch|endeavouros|manjaro|garuda|arcolinux)
        PKG_MANAGER="pacman"
        PKG_UPDATE="$PKG_MANAGER -Sy"
        PKG_INSTALL="$PKG_MANAGER -S --noconfirm"
        ;;
    opensuse*|suse)
        PKG_MANAGER="zypper"
        PKG_UPDATE="$PKG_MANAGER refresh"
        PKG_INSTALL="$PKG_MANAGER install -y"
        ;;
    *)
        warn "Unrecognized distro ($DISTRO). Will skip auto-install."
        PKG_MANAGER=""
        ;;
esac

# --- packages by distro family ---
pkg_names() {
    case "$DISTRO" in
        debian|ubuntu|pop|linuxmint|elementary|zorin)
            echo "wine curl python3 unzip zstd xdg-utils desktop-file-utils file"
            ;;
        fedora)
            echo "wine curl python3 unzip zstd xdg-utils desktop-file-utils file"
            ;;
        arch|endeavouros|manjaro|garuda|arcolinux)
            echo "wine curl python unzip zstd xdg-utils desktop-file-utils file"
            ;;
        opensuse*|suse)
            echo "wine curl python3 unzip zstd xdg-utils desktop-file-utils file"
            ;;
        *) echo "" ;;
    esac
}

# --- permission helper ---
SUDO_CMD=""
try_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        SUDO_CMD=""
    elif command -v sudo >/dev/null 2>&1; then
        SUDO_CMD="sudo"
    else
        SUDO_CMD=""
    fi
}

# --- check and optionally install deps ---
check_deps() {
    local MISSING=()

    for bin in wine curl python3 unzip zstd xdg-mime update-desktop-database file; do
        if ! command -v "$bin" >/dev/null 2>&1; then
            MISSING+=("$bin")
        fi
    done

    if [ ${#MISSING[@]} -eq 0 ]; then
        info "All prerequisites found."
        return
    fi

    warn "Missing commands: ${MISSING[*]}"

    # map binary names back to package names
    local NEED=()
    for bin in "${MISSING[@]}"; do
        case "$bin" in
            xdg-mime)                  NEED+=("xdg-utils") ;;
            update-desktop-database)   NEED+=("desktop-file-utils") ;;
            python3)                   case "$DISTRO" in
                                           arch|endeavouros|manjaro|garuda|arcolinux) NEED+=("python") ;;
                                           *) NEED+=("python3") ;;
                                       esac ;;
            *)                         NEED+=("$bin") ;;
        esac
    done

    if [ -z "$PKG_MANAGER" ]; then
        die "No package manager known for $DISTRO. Install manually: ${NEED[*]}"
    fi

    echo ""
    echo "The following packages need to be installed:"
    echo "  ${NEED[*]}"
    echo ""
    read -r -p "Install them now? [Y/n] " REPLY
    case "$REPLY" in
        n|N|no|NO) die "Aborted by user. Install manually: sudo $PKG_MANAGER ${NEED[*]}" ;;
        *) try_sudo ;;
    esac

    if [ -n "$SUDO_CMD" ]; then
        info "Updating package lists..."
        $SUDO_CMD bash -c "$PKG_UPDATE" 2>/dev/null || true
        info "Installing packages..."
        $SUDO_CMD $PKG_INSTALL "${NEED[@]}" || die "Package installation failed"
    else
        warn "No sudo access. Skipping package install."
        die "Install manually as root: $PKG_MANAGER ${NEED[*]}"
    fi
}

# ----------------------------------------------------------------
check_deps

WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"

# --- resolve latest vkd3d-proton ---
info "Resolving latest vkd3d-proton release..."
LATEST_URL="https://api.github.com/repos/HansKristian-Work/vkd3d-proton/releases/latest"
VKD3D_TAG=$(curl -sfL "$LATEST_URL" 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    print(d['tag_name'])
except: sys.exit(1)
" 2>/dev/null) || VKD3D_TAG=""

# fallback: web scrape
if [ -z "$VKD3D_TAG" ]; then
    VKD3D_TAG=$(curl -sL "$REPO_URL/releases/latest" -o /dev/null -w '%{url_effective}' 2>/dev/null | sed 's|.*/tag/||')
fi
# fallback: releases page
if [ -z "$VKD3D_TAG" ]; then
    VKD3D_TAG=$(curl -sL "$REPO_URL/releases" 2>/dev/null | grep -Eo 'tag/v[0-9]+\.[0-9]+\.[0-9]+' | head -1 | sed 's|tag/||')
fi

[ -n "$VKD3D_TAG" ] || die "Could not get latest vkd3d-proton tag (check internet?). Set VKD3D_TAG=v3.0.1 and re-run."

VKD3D_VER="${VKD3D_TAG#v}"
VKD3D_TAR="vkd3d-proton-${VKD3D_VER}.tar.zst"
VKD3D_URL="$REPO_URL/releases/download/$VKD3D_TAG/$VKD3D_TAR"

# --- paths ---
VORTEX_DIR="$HOME/Desktop/Vortex"
LOCAL_BIN="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
HANDLER_SCRIPT="$LOCAL_BIN/vortex-handler"
HANDLER_DESKTOP="$APPS_DIR/vortex-handler.desktop"
LAUNCHER_DIR="$VORTEX_DIR/APP_VAR/vortex-launcher"
LAUNCHER_SCRIPT="$VORTEX_DIR/APP_VAR/vortex-launcher.sh"
APPSEARCH_DIR="$VORTEX_DIR/appsearch"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ----------------------------------------------------------------
# 1. Download / update Vortex
# ----------------------------------------------------------------
download_vortex() {
    info "Downloading Vortex to Desktop..."
    curl -fL "$VORTEX_DL" -o "/tmp/Vortex-Windows.zip" || \
        die "Failed to download Vortex from $VORTEX_DL"
    # if zip has a single root folder, strip it; otherwise extract directly
    local tmpdir
    tmpdir=$(mktemp -d)
    unzip -qo "/tmp/Vortex-Windows.zip" -d "$tmpdir" || \
        die "Failed to extract Vortex client"
    local items=("$tmpdir"/*)
    if [ ${#items[@]} -eq 1 ] && [ -d "${items[0]}" ]; then
        mkdir -p "$VORTEX_DIR"
        cp -r "${items[0]}"/* "$VORTEX_DIR/"
    else
        mkdir -p "$VORTEX_DIR"
        cp -r "$tmpdir"/* "$VORTEX_DIR/"
    fi
    rm -rf "$tmpdir" "/tmp/Vortex-Windows.zip"
    info "    extracted to $VORTEX_DIR"
}

if [ -f "$VORTEX_DIR/Vortex.exe" ]; then
    echo ""
    info "Vortex already installed at $VORTEX_DIR"
    read -r -p "Re-download / update? [y/N] " REPLY
    case "$REPLY" in
        y|Y|yes|YES) download_vortex ;;
        *)            info "    keeping existing install" ;;
    esac
else
    download_vortex
fi

# ----------------------------------------------------------------
# 2. Organize Vortex installation
# ----------------------------------------------------------------
info "Organizing Vortex installation..."
mkdir -p "$VORTEX_DIR/bin" "$VORTEX_DIR/config"
if [ -f "$VORTEX_DIR/Vortex.exe" ] && [ ! -f "$VORTEX_DIR/bin/Vortex.exe" ]; then
    mv "$VORTEX_DIR/Vortex.exe" "$VORTEX_DIR/bin/"
fi
if [ -f "$VORTEX_DIR/receiver.exe" ] && [ ! -f "$VORTEX_DIR/bin/receiver.exe" ]; then
    mv "$VORTEX_DIR/receiver.exe" "$VORTEX_DIR/bin/"
fi
if [ ! -f "$VORTEX_DIR/config/usernamesandpasswords" ]; then
    cat > "$VORTEX_DIR/config/usernamesandpasswords" << 'CREDS'
username password
CREDS
fi
info "    bin/   → executables"
info "    config/ → credentials"

# ----------------------------------------------------------------
# 3. Download and install vkd3d-proton into Wine prefix
# ----------------------------------------------------------------
VKD3D_INSTALLED=false
if [ -f "$WINEPREFIX/drive_c/windows/system32/d3d12core.dll" ]; then
    VKD3D_INSTALLED=true
fi

if $VKD3D_INSTALLED; then
    info "VKD3D-proton already installed in Wine prefix"
else
    if [ -z "$VKD3D_TAG" ]; then
        echo ""
        warn "Could not auto-detect latest VKD3D-proton version (no internet?)."
        warn "Download it manually from:"
        warn "  https://github.com/HansKristian-Work/vkd3d-proton/releases"
        warn ""
        warn "Extract and run:"
        warn "  cd vkd3d-proton-* && WINEPREFIX=$WINEPREFIX ./setup_vkd3d_proton.sh install"
        warn ""
        read -r -p "Press Enter after installing VKD3D-proton manually, or Ctrl+C to abort"
    else
        info "Downloading VKD3D-proton $VKD3D_TAG..."
        curl -fL "$VKD3D_URL" -o "/tmp/$VKD3D_TAR" || \
            die "Failed to download VKD3D-proton"
        tar --zstd -xf "/tmp/$VKD3D_TAR" -C /tmp/ || \
            die "Failed to extract VKD3D-proton (zstd may be missing: apt install zstd)"
        WINEPREFIX="$WINEPREFIX" bash "/tmp/vkd3d-proton-${VKD3D_VER}/setup_vkd3d_proton.sh" install || \
            die "VKD3D-proton setup failed"
        rm -rf "/tmp/$VKD3D_TAR" "/tmp/vkd3d-proton-${VKD3D_VER}"
        info "    installed $VKD3D_TAG"
    fi
fi

# ----------------------------------------------------------------
# 4. Remove non-Wine dxgi.dll so WGPU falls back to Vulkan backend
# ----------------------------------------------------------------
if [ -f "$WINEPREFIX/drive_c/windows/system32/dxgi.dll" ]; then
    if ! file "$WINEPREFIX/drive_c/windows/system32/dxgi.dll" | grep -qi "pe32.*dll.*windows"; then
        info "Removing stale dxgi.dll..."
        mv "$WINEPREFIX/drive_c/windows/system32/dxgi.dll" \
           "$WINEPREFIX/drive_c/windows/system32/dxgi.dll.bak"
    fi
fi

# ----------------------------------------------------------------
# 5. Set Wine DLL overrides
# ----------------------------------------------------------------
info "Setting Wine DLL overrides..."
wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" \
    /v d3d12 /t REG_SZ /d native,builtin /f 2>/dev/null || true
wine reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" \
    /v d3d12core /t REG_SZ /d native,builtin /f 2>/dev/null || true

# ----------------------------------------------------------------
# 6. Create vortex-handler wrapper script
# ----------------------------------------------------------------
info "Creating vortex-handler script..."
mkdir -p "$LOCAL_BIN"
cat > "$HANDLER_SCRIPT" << WRAPPER
#!/bin/bash
# ensure receiver.exe is running
if ! pgrep -f "^wine.*receiver.exe" >/dev/null 2>&1; then
    wine "$VORTEX_DIR/bin/receiver.exe" </dev/null >/dev/null 2>&1 &
    disown
    sleep 1
fi
cd "$VORTEX_DIR"
exec wine "$VORTEX_DIR/bin/Vortex.exe" "\$@"
WRAPPER
chmod +x "$HANDLER_SCRIPT"

# ----------------------------------------------------------------
# 7. Register vortex:// protocol
# ----------------------------------------------------------------
info "Registering vortex:// protocol handler..."
mkdir -p "$APPS_DIR"
cat > "$HANDLER_DESKTOP" << DESKTOP
[Desktop Entry]
Type=Application
Name=Vortex
Exec=$HANDLER_SCRIPT %u
MimeType=x-scheme-handler/vortex;
StartupNotify=false
Categories=Game;
NoDisplay=true
DESKTOP

xdg-mime default vortex-handler.desktop x-scheme-handler/vortex 2>/dev/null || true
# also register via gio (used by Chromium, Chrome, Edge)
command -v gio >/dev/null 2>&1 && \
    gio mime x-scheme-handler/vortex vortex-handler.desktop 2>/dev/null || true
update-desktop-database "$APPS_DIR" 2>/dev/null || true

# ----------------------------------------------------------------
# 8. Start receiver daemon
# ----------------------------------------------------------------
if ! pgrep -f "^wine.*receiver.exe" >/dev/null 2>&1; then
    info "Starting receiver.exe..."
    wine "$VORTEX_DIR/bin/receiver.exe" </dev/null >/dev/null 2>&1 &
    disown
fi

# ----------------------------------------------------------------
# 9. Deploy APP_VAR (launcher)
# ----------------------------------------------------------------
info "Deploying web app launcher..."
APP_VAR_SOURCE="$SCRIPT_DIR/APP_VAR"
if [ -d "$APP_VAR_SOURCE" ]; then
    rm -rf "$VORTEX_DIR/APP_VAR"
    cp -r "$APP_VAR_SOURCE" "$VORTEX_DIR/APP_VAR"
    info "    APP_VAR deployed from $APP_VAR_SOURCE"
else
    warn "No APP_VAR directory found alongside this script."
    warn "The launcher won't be installed. Provide APP_VAR in:"
    warn "  $APP_VAR_SOURCE"
    warn "Then re-run this script to install it."
fi

# ----------------------------------------------------------------
# 10. Install Node.js (via nvm)
# ----------------------------------------------------------------
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    info "Installing nvm..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
fi
. "$NVM_DIR/nvm.sh"

if ! command -v node &>/dev/null; then
    info "Installing latest Node.js via nvm..."
    nvm install node
    nvm alias default node
fi

info "Node: $(node --version)  npm: $(npm --version)"

if [ -d "$VORTEX_DIR/APP_VAR/vortex-launcher" ]; then
    info "Installing launcher dependencies..."
    npm --prefix "$VORTEX_DIR/APP_VAR/vortex-launcher" install --no-audit
    chmod +x "$LAUNCHER_SCRIPT"
else
    warn "Skipping npm install — APP_VAR not deployed"
fi

# ----------------------------------------------------------------
# 11. Create appsearch tool
# ----------------------------------------------------------------
info "Creating AppSearch tool..."
mkdir -p "$APPSEARCH_DIR"
cat > "$APPSEARCH_DIR/appsearch.sh" << 'SEARCH'
#!/usr/bin/env bash
set -euo pipefail
APPSEARCH_DIR="$(cd "$(dirname "$0")" && pwd)"
VORTEX_DIR="$(dirname "$APPSEARCH_DIR")"
if [ -n "${1:-}" ]; then
    echo "Searching Vortex for: $1"
    find "$VORTEX_DIR" -iname "*$1*" \
        -not -path "*/node_modules/*" \
        -not -path "*/target/*" \
        -not -path "*/__pycache__/*" \
        -not -path "*/assets/*" \
        -not -path "*/.git/*" 2>/dev/null | head -50
else
    echo "Vortex AppSearch — usage: $0 <search-term>"
    xdg-open "$APPSEARCH_DIR" 2>/dev/null || true
fi
SEARCH
chmod +x "$APPSEARCH_DIR/appsearch.sh"

# ----------------------------------------------------------------
# 12. Desktop shortcuts
# ----------------------------------------------------------------
info "Creating desktop shortcuts..."
mkdir -p "$APPS_DIR"

if [ -f "$LAUNCHER_SCRIPT" ]; then
    cat > "$APPS_DIR/vortex-launcher.desktop" << DESKTOP
[Desktop Entry]
Name=Vortex Launcher
Comment=Play Vortex — playvortex.io webview + game launcher
Exec=$LAUNCHER_SCRIPT
Icon=$VORTEX_DIR/assets/icon.ico
Terminal=false
Type=Application
Categories=Game;
StartupNotify=true
DESKTOP
    chmod 644 "$APPS_DIR/vortex-launcher.desktop"
fi

# Also place on Desktop if it exists
XDG_DESKTOP_DIR="${XDG_DESKTOP_DIR:-$HOME/Desktop}"
if [ -d "$XDG_DESKTOP_DIR" ]; then
    cp "$APPS_DIR/vortex-launcher.desktop" "$XDG_DESKTOP_DIR/" 2>/dev/null || true
    chmod 755 "$XDG_DESKTOP_DIR/vortex-launcher.desktop" 2>/dev/null || true
fi

update-desktop-database "$APPS_DIR" 2>/dev/null || true

# ----------------------------------------------------------------
echo ""
echo "================================="
echo "  Vortex setup complete!"
echo "================================="
echo ""
echo "  Client:   $VORTEX_DIR"
echo "  Handler:  $HANDLER_SCRIPT"
echo "  Launcher: $LAUNCHER_DIR"
echo "  AppSearch: $APPSEARCH_DIR"
echo ""
echo "Desktop shortcut installed:"
echo "  - Vortex Launcher  (webview + game launch)"
echo ""
echo "Next: restart your browser, visit vortex.towerstats.com,"
echo "and click Play (accept the vortex:// prompt)."
echo "If your browser doesn't prompt, paste this in the address bar:"
echo "  vortex://"
echo "Then set Vortex as the default handler."
echo ""
