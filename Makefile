# Define the shell
SHELL := /bin/bash

# --- Variables ---
UV := uv
SCARB := scarb
CARGO := cargo

# Directories to remove on 'clean'
CLEAN_DIRS := .venv db

# --- Targets ---

# Ensure these targets are always run, even if files with these names exist
.PHONY: all setup build test clean help

# Default target: running 'make' will default to 'make all'
all: clean setup build test

# Setup the environment: sync Python deps and check Rust code
setup:
	@echo "--- 🚀 Setting up environment: Syncing Python dependencies and checking Rust code ---"
	$(UV) sync
	$(CARGO) check

# Build the projects in release mode
build:
	@echo "--- 🏗️ Building projects (Release): Scarb and Cargo ---"
	$(SCARB) build
	$(CARGO) build --release

# Run tests
test:
	@echo "--- 🧪 Running tests: Building Scarb tests and running Cargo nextest ---"
	$(SCARB) build -p tests
	$(CARGO) nextest run --no-fail-fast

# Clean up artifacts, virtual environments, and caches
clean:
	@echo "--- 🧹 Cleaning up: Removing build artifacts, venv, db, and caches ---"
	rm -rf $(CLEAN_DIRS)
	$(UV) cache clean
	$(CARGO) clean

# Self-documenting help target
help:
	@echo "Available commands:"
	@echo "  make setup    - Sync Python 'uv' environment and check Rust code."
	@echo "  make build    - Build the Scarb and Rust projects (release mode). (Default)"
	@echo "  make test     - Run 'setup' then build Scarb tests and run Rust tests."
	@echo "  make clean    - Remove build artifacts, .venv, db, and clean caches."
	@echo "  make all      - Alias for 'make build'."