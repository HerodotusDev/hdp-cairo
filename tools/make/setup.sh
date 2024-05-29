#!/bin/bash

VENV_PATH=${1:-venv}
PYTHON_VERSION=${2:-3.9}

echo "Setting up virtual environment at $VENV_PATH with Python $PYTHON_VERSION"

# Function to install GNU parallel
install_parallel() {
    echo "Installing GNU parallel..."
    case "$OSTYPE" in
        linux-gnu*)
            # Linux
            if command -v apt-get >/dev/null; then
                sudo apt-get update && sudo apt-get install -y parallel
            elif command -v dnf >/dev/null; then
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
    install_parallel
else
    echo "GNU parallel is already installed."
fi

# Check Python version compatibility
if ! command -v python"$PYTHON_VERSION" >/dev/null; then
    echo "Python $PYTHON_VERSION is not installed. Please install it and try again."
    exit 1
fi

# Create virtual environment
echo "Creating virtual environment..."
python"$PYTHON_VERSION" -m venv "$VENV_PATH"
echo 'export PYTHONPATH="$PWD:$PYTHONPATH"' >> "$VENV_PATH/bin/activate"
source "$VENV_PATH/bin/activate" || { echo "Failed to activate virtual environment."; exit 1; }

# Update dependencies
echo "Updating dependencies..."
pip install -U pip setuptools wheel || { echo "Failed to update pip."; exit 1; }
pip install -r tools/make/requirements.txt || { echo "Failed to install requirements."; exit 1; }
pip install . || { echo "Failed to install the package."; exit 1; }

# Update submodules
echo "Updating git submodules..."
git submodule update --init || { echo "Failed to update git submodules."; exit 1; }
