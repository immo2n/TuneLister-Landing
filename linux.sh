#!/bin/bash
set -e

# Colors
NC='\033[0m'
BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
BLUE='\033[34m'

# Status indicators
info() {
  echo -e "${CYAN}${BOLD}[i]${NC} $1"
}
success() {
  echo -e "${GREEN}${BOLD}[+]${NC} $1"
}
warn() {
  echo -e "${YELLOW}${BOLD}[!]${NC} $1"
}
error() {
  echo -e "${RED}${BOLD}[-]${NC} $1"
}

# Clean banner
echo -e "${GREEN}${BOLD}"
echo "  _____                _      _     _            "
echo " |_   _|              | |    (_)   | |           "
echo "   | | _   _ _ __   ___| |     _ ___| |_ ___ _ __"
echo "   | || | | | '_ \ / _ \ |    | / __| __/ _ \ '__|"
echo "   | || |_| | | | |  __/ |____| \__ \ ||  __/ |   "
echo "   \_/ \__,_|_| |_|\___\_____/|_|___/\__\___|_|   "
echo ""
echo -e "         ${CYAN}TuneLister Installer for Linux${NC}"
echo -e "${GREEN}${BOLD}================================================================${NC}"
echo ""

# 1. Detect System Architecture
SYS_ARCH=$(uname -m)
if [ "$SYS_ARCH" != "x86_64" ]; then
  error "TuneLister Linux build currently only supports x86_64 (64-bit Intel/AMD) architectures. Detected: $SYS_ARCH"
  exit 1
fi

# Helper function to check if a URL exists
url_exists() {
  local url="$1"
  if command -v curl >/dev/null 2>&1; then
    local status
    status=$(curl -L -s -o /dev/null -I -w "%{http_code}" -H "Cache-Control: no-cache" -H "Pragma: no-cache" "$url" || true)
    if [ "$status" = "200" ]; then
      return 0
    fi
  else
    if wget --spider -q --header="Cache-Control: no-cache" --header="Pragma: no-cache" "$url" >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

# Helper function to verify sha256 hash
verify_hash() {
  local file_path="$1"
  local hash_file="$2"
  
  if ! command -v sha256sum >/dev/null 2>&1; then
    warn "sha256sum not found, skipping hash verification for safety."
    return 0
  fi
  
  local expected_hash
  expected_hash=$(cat "$hash_file" | tr -d '[:space:]')
  
  local actual_hash
  actual_hash=$(sha256sum "$file_path" | cut -d' ' -f1 | tr -d '[:space:]')
  
  if [ "$expected_hash" = "$actual_hash" ]; then
    return 0
  else
    error "Hash mismatch for $file_path!"
    echo -e "    Expected: ${BOLD}$expected_hash${NC}"
    echo -e "    Actual:   ${BOLD}$actual_hash${NC}"
    return 1
  fi
}

# 2. Check latest version
info "Checking latest release version..."
LATEST_JSON_URL="https://raw.githubusercontent.com/immo2n/TuneLister-dist/main/latest.json"

if command -v curl >/dev/null 2>&1; then
  JSON_DATA=$(curl -s -H "Cache-Control: no-cache" -H "Pragma: no-cache" "$LATEST_JSON_URL" || true)
else
  JSON_DATA=$(wget -qO- --header="Cache-Control: no-cache" --header="Pragma: no-cache" "$LATEST_JSON_URL" || true)
fi

VERSION_PART=""
BUILD_PART=""
if [ -n "$JSON_DATA" ]; then
  if echo "$JSON_DATA" | grep -qP '"version":' 2>/dev/null; then
    VERSION_PART=$(echo "$JSON_DATA" | grep -oP '"version":\s*"\K[^"]+' || true)
    BUILD_PART=$(echo "$JSON_DATA" | grep -oP '"build_name":\s*"\K[^"]+' || true)
  else
    VERSION_PART=$(echo "$JSON_DATA" | grep -o '"version":[^,]*' | cut -d'"' -f4 || true)
    BUILD_PART=$(echo "$JSON_DATA" | grep -o '"build_name":[^,]*' | cut -d'"' -f4 || true)
  fi
fi

if [ -n "$VERSION_PART" ]; then
  if [ -n "$BUILD_PART" ]; then
    LATEST_VERSION="${VERSION_PART}-${BUILD_PART}"
  else
    LATEST_VERSION="${VERSION_PART}"
  fi
  success "Latest version resolved: ${BOLD}${LATEST_VERSION}${NC}"
else
  LATEST_VERSION="1.0.0-stable"
  warn "Failed to query latest version automatically, using fallback: ${BOLD}${LATEST_VERSION}${NC}"
fi

# 3. Create download directory and check/download the binary files
DOWNLOAD_DIR="/tmp/tunelister-install"
rm -rf "$DOWNLOAD_DIR"
mkdir -p "$DOWNLOAD_DIR"

DIST_BASE_URL="https://raw.githubusercontent.com/immo2n/TuneLister-dist/main/${LATEST_VERSION}/linux"

GUI_URL="${DIST_BASE_URL}/tunelister-online"
GUI_HASH_URL="${DIST_BASE_URL}/tunelister-online.hash"

if ! url_exists "$GUI_URL" || ! url_exists "$GUI_HASH_URL"; then
  error "Installation files not found for version ${BOLD}${LATEST_VERSION}${NC} on architecture x86_64."
  exit 1
fi

INSTALL_DIR="$HOME/.TuneLister"
mkdir -p "$INSTALL_DIR"

UP_TO_DATE=false
if [ -f "$INSTALL_DIR/tunelister-online" ]; then
  CURRENT_SIG=$("$INSTALL_DIR/tunelister-online" -v 2>/dev/null || true)
  if [[ "$CURRENT_SIG" == *"${LATEST_VERSION}"* ]]; then
    UP_TO_DATE=true
    success "TuneLister is already at the latest version (${LATEST_VERSION}). Skipping download."
  fi
fi

if [ "$UP_TO_DATE" = false ]; then
  info "Downloading TuneLister from: ${BLUE}${GUI_URL}${NC}"
  if command -v curl >/dev/null 2>&1; then
    curl -L -H "Cache-Control: no-cache" -H "Pragma: no-cache" -o "$DOWNLOAD_DIR/tunelister-online" "$GUI_URL"
    curl -L -H "Cache-Control: no-cache" -H "Pragma: no-cache" -o "$DOWNLOAD_DIR/tunelister-online.hash" "$GUI_HASH_URL"
  else
    wget --header="Cache-Control: no-cache" --header="Pragma: no-cache" -O "$DOWNLOAD_DIR/tunelister-online" "$GUI_URL"
    wget --header="Cache-Control: no-cache" --header="Pragma: no-cache" -O "$DOWNLOAD_DIR/tunelister-online.hash" "$GUI_HASH_URL"
  fi

  info "Verifying integrity of TuneLister..."
  if ! verify_hash "$DOWNLOAD_DIR/tunelister-online" "$DOWNLOAD_DIR/tunelister-online.hash"; then
    error "Integrity check failed for TuneLister. Aborting installation."
    exit 1
  fi

  info "Installing TuneLister to ${BLUE}${INSTALL_DIR}${NC}..."
  cp "$DOWNLOAD_DIR/tunelister-online" "$INSTALL_DIR/tunelister-online"
  chmod +x "$INSTALL_DIR/tunelister-online"
fi

# 4. Download and install external dependencies if missing
DEPS_BIN_DIR="$INSTALL_DIR/app-data/bin"
mkdir -p "$DEPS_BIN_DIR"

if [ ! -f "$DEPS_BIN_DIR/yt-dlp" ] || [ ! -f "$DEPS_BIN_DIR/ffmpeg" ]; then
  info "Downloading Linux dependencies (yt-dlp, ffmpeg)..."
  DEPS_URL="https://github.com/immo2n/TuneLister-dist/releases/download/deps/linux_deps.zip"
  
  if command -v curl >/dev/null 2>&1; then
    curl -L -o "$DOWNLOAD_DIR/linux_deps.zip" "$DEPS_URL"
  else
    wget -O "$DOWNLOAD_DIR/linux_deps.zip" "$DEPS_URL"
  fi
  
  info "Extracting dependencies..."
  if command -v unzip >/dev/null 2>&1; then
    unzip -o "$DOWNLOAD_DIR/linux_deps.zip" -d "$DEPS_BIN_DIR" >/dev/null
    
    # Rename to match expected backend binary names
    if [ -f "$DEPS_BIN_DIR/yt-dlp_linux" ]; then
      mv "$DEPS_BIN_DIR/yt-dlp_linux" "$DEPS_BIN_DIR/yt-dlp"
    fi
    if [ -f "$DEPS_BIN_DIR/ffmpeg_linux" ]; then
      mv "$DEPS_BIN_DIR/ffmpeg_linux" "$DEPS_BIN_DIR/ffmpeg"
    fi
    
    chmod +x "$DEPS_BIN_DIR/yt-dlp" "$DEPS_BIN_DIR/ffmpeg"
    success "Dependencies installed successfully in app-data/bin."
  else
    warn "unzip command not found! Please manually extract ${BLUE}${DOWNLOAD_DIR}/linux_deps.zip${NC} into ${BLUE}${DEPS_BIN_DIR}${NC} and rename the binaries to 'yt-dlp' and 'ffmpeg'."
  fi
fi

# 5. Generate the 'uninstall.sh' uninstaller script
UNINSTALLER_PATH="$INSTALL_DIR/uninstall.sh"
info "Generating uninstaller script at ${BLUE}${UNINSTALLER_PATH}${NC}..."
cat << 'EOF' > "$UNINSTALLER_PATH"
#!/bin/bash

# Colors
NC='\033[0m'
BOLD='\033[1m'
YELLOW='\033[33m'
RED='\033[31m'

echo "=============================================="
echo "      TuneLister Uninstaller for Linux"
echo "=============================================="

# Confirmation prompt
read -p "$(echo -e "${YELLOW}${BOLD}[?]${NC} Are you sure you want to completely uninstall TuneLister? (y/N): ")" CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY](es)?$ ]]; then
  echo -e "${RED}${BOLD}[-]${NC} Uninstall cancelled."
  exit 0
fi

# Stop the application if running
echo "[+] Stopping any running instances of TuneLister..."
pkill -x tunelister-onli || pkill -x tunelister-online || true

# Remove desktop shortcuts
echo "[+] Removing desktop shortcut..."
rm -f "$HOME/.local/share/applications/tunelister.desktop"

# Update desktop shortcut database if helper utility is present
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
fi

# Remove uninstaller command symlink
echo "[+] Removing terminal command symlink..."
rm -f "$HOME/.local/bin/remove-tunelister"

# Remove application files but preserve app-data directory
echo "[+] Cleaning up application files (preserving your local playlists, history, and cache)..."
rm -f "$HOME/.TuneLister/tunelister-online"
rm -f "$HOME/.TuneLister/logo.png"

# Remove itself
echo "[+] Cleaning up uninstaller..."
rm -f "$HOME/.TuneLister/uninstall.sh"

echo "=============================================="
echo "  TuneLister Uninstalled Successfully!"
echo "=============================================="
echo ""
EOF
chmod +x "$UNINSTALLER_PATH"

# Generate terminal uninstaller command symlink
mkdir -p "$HOME/.local/bin"
ln -sf "$UNINSTALLER_PATH" "$HOME/.local/bin/remove-tunelister"

# 5. Check if Desktop Entry is supported
DESKTOP_SUPPORTED=false
if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
  DESKTOP_SUPPORTED=true
fi

if [ "$DESKTOP_SUPPORTED" = true ]; then
  info "Desktop environment detected. Configuring desktop launcher..."
  
  # Create local applications directory
  APPS_DIR="$HOME/.local/share/applications"
  mkdir -p "$APPS_DIR"
  
  # Download logo as icon to ~/.TuneLister/logo.png
  ICON_PATH="$INSTALL_DIR/logo.png"
  ICON_URL="https://tunelister.vercel.app/logo.png"
  
  info "Downloading app icon to ${BLUE}${ICON_PATH}${NC}..."
  if command -v curl >/dev/null 2>&1; then
    curl -L -s -H "Cache-Control: no-cache" -H "Pragma: no-cache" -o "$ICON_PATH" "$ICON_URL" || true
  else
    wget -q --header="Cache-Control: no-cache" --header="Pragma: no-cache" -O "$ICON_PATH" "$ICON_URL" || true
  fi
  
  # Create the .desktop launcher file using the absolute path to the icon
  cat <<EOF > "$APPS_DIR/tunelister.desktop"
[Desktop Entry]
Type=Application
Name=TuneLister
Comment=Your Music, Unleashed - Standalone Audio Streamer
Exec=$INSTALL_DIR/tunelister-online
Icon=$ICON_PATH
Terminal=false
Categories=AudioVideo;Audio;Player;Utility;
StartupNotify=true
EOF
  chmod +x "$APPS_DIR/tunelister.desktop"

  # Update desktop shortcut database if helper utility is present
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
  fi
  success "Desktop application entry registered successfully."
fi

# 6. Clean up download cache
rm -rf "$DOWNLOAD_DIR"

# 7. Success message
echo ""
echo -e "${GREEN}${BOLD}┌──────────────────────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}${BOLD}│             TuneLister Installed Successfully!               │${NC}"
echo -e "${GREEN}${BOLD}└──────────────────────────────────────────────────────────────┘${NC}"
echo -e "  ${BOLD}Version:${NC}      ${GREEN}${LATEST_VERSION}${NC}"
echo -e "  ${BOLD}GUI Binary:${NC}   ${BLUE}${INSTALL_DIR}/tunelister-online${NC}"
echo -e "  ${BOLD}App Directory:${NC}${CYAN}~/.TuneLister${NC}"
echo -e "  ${BOLD}Uninstall:${NC}    ${RED}~/.TuneLister/uninstall.sh${NC}"
echo -e "${GREEN}${BOLD}────────────────────────────────────────────────────────────────${NC}"
echo ""

# Start the desktop application
if [ "$DESKTOP_SUPPORTED" = true ]; then
  info "Starting TuneLister Desktop App..."
  nohup "$INSTALL_DIR/tunelister-online" >/dev/null 2>&1 &
  success "App started! Enjoy your music!"
fi
echo ""
