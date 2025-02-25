#!/bin/bash

VENV_PATH=${1:-venv}
PYTHON_VERSION=${2:-3.10}

echo "Setting up virtual environment at $VENV_PATH with Python $PYTHON_VERSION"

# Check Python version compatibility and get full path
PYTHON_PATH=$(which python${PYTHON_VERSION}) || {
    echo "Python $PYTHON_VERSION is not installed. Please install it and try again."
    exit 1
}

echo "Using Python at: $PYTHON_PATH"

# Create virtual environment with explicit Python version
echo "Creating virtual environment..."
"$PYTHON_PATH" -m venv "$VENV_PATH"
echo 'export PYTHONPATH="$PWD:$PYTHONPATH"' >> "$VENV_PATH/bin/activate"
source "$VENV_PATH/bin/activate" || { echo "Failed to activate virtual environment."; exit 1; }

# Update dependencies
echo "Installing dependencies"
# pip install packages/cairo-lang-0.13.1.zip || { echo "Failed to install cairo-lang-0.13.1."; exit 1; }

pip install cairo-lang garaga

# Update submodules
echo "Updating git submodule..."
git submodule update --init || { echo "Failed to update git submodules."; exit 1; }

# Create virtual environment
if ! python3.10 -m venv venv; then
    echo "Failed to create virtual environment with python3.10"
    exit 1
fi

echo 'export PYTHONPATH="$PWD:$PWD/packages/garaga_zero:$PYTHONPATH"' >> venv/bin/activate
source venv/bin/activate

pip install uv
uv pip compile packages/garaga_zero/pyproject.toml --output-file packages/garaga_zero/tools/make/requirements.txt -q
uv pip install -r packages/garaga_zero/tools/make/requirements.txt

pip install py_ecc

echo "Applying patch to instances.py..."
patch venv/lib/python3.10/site-packages/starkware/lang/instances.py < packages/garaga_zero/tools/make/instances.patch

echo "Applying patch to extension_field_modulo_circuit.py..."
patch venv/lib/python3.10/site-packages/garaga/extension_field_modulo_circuit.py < packages/garaga_zero/tools/make/extension_field_modulo_circuit.patch

deactivate

echo "Setup Complete!"