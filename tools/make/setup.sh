#!/bin/bash

VENV_PATH=${1:-venv}

echo "Setting up virtual environment at $VENV_PATH"

# Function to install GNU parallel
install_parallel() {
    case "$OSTYPE" in
        linux-gnu*)
            # Linux
            if command -v apt-get >/dev/null; then
                # Debian/Ubuntu
                sudo apt-get update && sudo apt-get install -y parallel
            elif command -v dnf >/dev/null; then
                # Fedora
                sudo dnf install -y parallel
            else
                echo "Unsupported Linux distribution for automatic parallel installation."
                exit 1
            fi
            ;;
        darwin*)
            # macOS
            if command -v brew >/dev/null; then
                brew install parallel
            else
                echo "Homebrew is not installed. Please install Homebrew and try again."
                exit 1
            fi
            ;;
        *)
            echo "Unsupported operating system for automatic parallel installation."
            exit 1
            ;;
    esac
}

# Check if parallel is installed, if not, attempt to install it
if ! command -v parallel >/dev/null; then
    echo "GNU parallel not found. Attempting to install..."
    install_parallel
else
    echo "GNU parallel is already installed."
fi

# Your existing setup script continues here...
python3.9 -m venv "$VENV_PATH"
echo 'export PYTHONPATH="$PWD:$PYTHONPATH"' >> "$VENV_PATH/bin/activate"
source "$VENV_PATH/bin/activate"
pip install -r tools/make/requirements.txt
git submodule init
git submodule update

git clone https://github.com/lambdaclass/cairo-vm.git
cd cairo-vm
git checkout 2e24b6a15704e038f4a15dfdb89c13ab14cba569
cd cairo1-run
cargo install --path .
cd ../../

pip install .