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

# Installation directory
INSTALL_DIR="${HDP_INSTALL_DIR:-$HOME/.local/bin}"
mkdir -p "$INSTALL_DIR"

echo "Downloading hdp-cli..."
curl -L "$DOWNLOAD_URL" -o "$INSTALL_DIR/hdp-cli"
chmod +x "$INSTALL_DIR/hdp-cli"

echo "hdp-cli has been installed to $INSTALL_DIR/hdp-cli"

# Add to PATH if needed
case ":${PATH}:" in
    *":$INSTALL_DIR:"*) : ;; # Already in PATH
    *)
        echo "Adding $INSTALL_DIR to PATH..."
        # Handle different shell types
        if [ -n "$BASH_VERSION" ]; then
            SHELL_RC="$HOME/.bashrc"
        elif [ -n "$ZSH_VERSION" ]; then
            SHELL_RC="$HOME/.zshrc"
        else
            SHELL_RC="$HOME/.profile"  # Fallback for other shells
        fi
        echo 'export PATH="'$INSTALL_DIR':$PATH"' >> "$SHELL_RC"
        export PATH="$INSTALL_DIR:$PATH"
        echo "Added to $SHELL_RC. The change will be permanent after restart or running: source $SHELL_RC"
        ;;
esac