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

# --- Quality gates (stable default + optional nightly/STWO lane) ---

.PHONY: fmt fmt-check clippy test-stable test-all-features future-incompat check dev lint

fmt:
	$(CARGO) fmt --all

fmt-check:
	$(CARGO) fmt --all -- --check

# Stable-by-default clippy: do NOT use --all-features because `stwo` pulls nightly-only deps.
clippy:
	$(CARGO) clippy --workspace --all-targets -- -D warnings

# Default tests (stable-compatible). Integration tests are ignored by default.
test-stable:
	$(CARGO) test --workspace --all-targets

# All-features tests run through the unified nightly toolchain.
test-all-features:
	$(CARGO) test --workspace --all-targets --all-features

# One-shot check: stable lane only (fast + deterministic).
check: fmt-check clippy test-stable

# Track future-incompatibility warnings reported by Rust (non-fatal today, fatal in future toolchains).
future-incompat:
	$(CARGO) report future-incompatibilities

# Development workflow
dev: fmt clippy test-stable
	@echo "--- Development checks passed ---"

# Full lint
lint: fmt-check clippy
	@echo "--- All lint checks passed ---"

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
	@echo "  make future-incompat - Show Rust future-incompatibility report (helps address warnings like 'size-of')."
	@echo "  make clean    - Remove build artifacts, .venv, db, and clean caches."
	@echo "  make all      - Alias for 'make build'."