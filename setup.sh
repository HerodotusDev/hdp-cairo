#!/bin/bash

# Update submodules
echo "Updating git submodules..."
git submodule update --init || { echo "Failed to update git submodules."; exit 1; }

VENV_PATH=${1:-venv}
PYTHON_VERSION=${2:-3.9}

echo "Setting up virtual environment at $VENV_PATH with Python $PYTHON_VERSION"

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
echo "Installing dependencies"
pip install packages/cairo-lang-0.13.3.zip || { echo "Failed to install cairo-lang-0.13.3."; exit 1; }
