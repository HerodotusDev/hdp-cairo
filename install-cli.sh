#!/bin/bash
set -e

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Convert architecture names
case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Set binary name based on OS
case $OS in
    linux)
        BINARY_NAME="hdp-cli-linux-${ARCH}"
        ;;
    darwin)
        BINARY_NAME="hdp-cli-macos-${ARCH}"
        ;;
    *)
        echo "Unsupported operating system: $OS"
        exit 1
        ;;
esac

# Get latest release version if not specified
if [ -z "$VERSION" ]; then
    VERSION=$(curl -s https://api.github.com/repos/HerodotusDev/hdp-cairo/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
fi

# Download URL
DOWNLOAD_URL="https://github.com/HerodotusDev/hdp-cairo/releases/download/${VERSION}/${BINARY_NAME}"
DRY_RUN_JSON_URL="https://github.com/HerodotusDev/hdp-cairo/releases/download/${VERSION}/dry_run_compiled.json"
SOUND_RUN_JSON_URL="https://github.com/HerodotusDev/hdp-cairo/releases/download/${VERSION}/sound_run_compiled.json"

# Installation directory structure
BASE_DIR="${HDP_INSTALL_DIR:-$HOME/.local/share/hdp}"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BASE_DIR"
mkdir -p "$BIN_DIR"

# Check for existing installation
if [ -f "$BIN_DIR/hdp-cli" ] || [ -f "$BASE_DIR/dry_run_compiled.json" ] || [ -f "$BASE_DIR/sound_run_compiled.json" ]; then
    echo "Existing HDP installation found."
    read -p "Do you want to overwrite the existing installation? (y/N) " -n 1 -r < /dev/tty
    echo
    if [[ "$REPLY" != [Yy] ]]; then
        echo "Installation cancelled."
        exit 1
    fi
    echo "Proceeding with installation..."
fi

echo "Downloading hdp-cli..."
curl -L "$DOWNLOAD_URL" -o "$BIN_DIR/hdp-cli"
chmod +x "$BIN_DIR/hdp-cli"

echo "Downloading JSON files..."
curl -L "$DRY_RUN_JSON_URL" -o "$BASE_DIR/dry_run_compiled.json"
curl -L "$SOUND_RUN_JSON_URL" -o "$BASE_DIR/sound_run_compiled.json"

echo "hdp-cli has been installed to $BIN_DIR/"
echo "JSON files have been installed to $BASE_DIR/"

# Output the export commands
echo
echo "Please add the following lines to your shell configuration file ($SHELL_RC):"
echo "export HDP_DRY_RUN_PATH=\"$BASE_DIR/dry_run_compiled.json\""
echo "export HDP_SOUND_RUN_PATH=\"$BASE_DIR/sound_run_compiled.json\""
echo
echo "Or run these commands in your current shell"

# Add to PATH if needed
case ":${PATH}:" in
    *":$BIN_DIR:"*) : ;; # Already in PATH
    *)
        echo "Adding $BIN_DIR to PATH..."
        # Handle different shell types
        if [ -n "$BASH_VERSION" ]; then
            SHELL_RC="$HOME/.bashrc"
        elif [ -n "$ZSH_VERSION" ]; then
            SHELL_RC="$HOME/.zshrc"
        else
            SHELL_RC="$HOME/.profile"  # Fallback for other shells
        fi
        echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$SHELL_RC"
        echo "export HDP_DRY_RUN_PATH=\"$BASE_DIR/dry_run_compiled.json\"" >> "$SHELL_RC"
        echo "export HDP_SOUND_RUN_PATH=\"$BASE_DIR/sound_run_compiled.json\"" >> "$SHELL_RC"
        export PATH="$BIN_DIR:$PATH"
        ;;
esac
