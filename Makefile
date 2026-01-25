# Define the shell
SHELL := /bin/bash
.SHELLFLAGS := -e -o pipefail -c
MAKEFLAGS += --no-builtin-rules --no-builtin-variables
.DEFAULT_GOAL := all

# --- Tools (override via env) ---
UV ?= uv
SCARB ?= scarb
CARGO ?= cargo
MDBOOK ?= mdbook
DOCKER ?= docker

# --- Paths ---
VENV_BIN := .venv/bin
CAIRO_FORMAT := $(VENV_BIN)/cairo-format

# Docker
DOCKER_TAG ?= hdp-cairo
DOCKER_TTY := $(shell if [ -t 1 ]; then echo "-t"; fi)
DOCKER_RUN_FLAGS ?= --rm -i $(DOCKER_TTY)

# Directories to remove on 'clean'
CLEAN_DIRS := .venv db

# --- Targets ---
.PHONY: all help setup venv versions rust-check \
	fmt fmt-check rust-fmt rust-fmt-check scarb-fmt scarb-fmt-check cairo-fmt cairo-fmt-check \
	clippy lint check dev ci future-incompat \
	build build-release scarb-build scarb-build-tests \
	test test-stable test-all-features test-nextest test-cargo \
	docs-build docs-serve \
	docker-build docker-run \
	clean

all: clean setup build test ## Clean, setup, build, test

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nAvailable commands:\n"} \
		/^[a-zA-Z0-9][a-zA-Z0-9_-]*:.*##/ { printf "  %-24s %s\n", $$1, $$2 } \
		END { printf "\n" }' $(MAKEFILE_LIST)

versions: ## Show toolchain versions
	@rustc --version
	@$(CARGO) --version
	@$(SCARB) --version
	@$(UV) --version

setup: ## Sync Python deps and check Rust
	@echo "--- Setting up environment: uv sync + cargo check ---"
	$(UV) sync
	$(CARGO) check --workspace --all-targets

venv: $(CAIRO_FORMAT) ## Ensure Cairo0 tooling installed

rust-check: ## Cargo check workspace
	$(CARGO) check --workspace --all-targets

build: scarb-build build-release ## Build Scarb + Rust (release)

build-release: ## Cargo build release
	$(CARGO) build --release

scarb-build: ## Scarb build
	$(SCARB) build

scarb-build-tests: ## Scarb build tests package
	$(SCARB) build -p tests

fmt: rust-fmt scarb-fmt cairo-fmt ## Format Rust, Cairo1, Cairo0
fmt-check: rust-fmt-check scarb-fmt-check cairo-fmt-check ## Check formatting

rust-fmt: ## Format Rust
	$(CARGO) fmt --all

rust-fmt-check: ## Check Rust formatting
	$(CARGO) fmt --all -- --check

scarb-fmt: ## Format Cairo1 with Scarb
	$(SCARB) fmt

scarb-fmt-check: ## Check Cairo1 formatting with Scarb
	$(SCARB) fmt --check

$(CAIRO_FORMAT): pyproject.toml uv.lock
	$(UV) sync

cairo-fmt: $(CAIRO_FORMAT) ## Format Cairo0 in src/
	$(CAIRO_FORMAT) -i src/*.cairo

cairo-fmt-check: $(CAIRO_FORMAT) ## Check Cairo0 formatting in src/
	$(CAIRO_FORMAT) -c src/*.cairo

# Stable-by-default clippy: do NOT use --all-features because `stwo` pulls nightly-only deps.
clippy: ## Run clippy (workspace, all targets)
	$(CARGO) clippy --workspace --all-targets -- -D warnings

lint: fmt-check clippy ## Run format checks + clippy

check: fmt-check clippy test-stable ## Run format checks, clippy, tests

dev: fmt clippy test-stable ## Format, clippy, and run tests

ci: fmt-check clippy test-stable ## CI-friendly checks

test: scarb-build-tests test-nextest ## Build Scarb tests + run nextest

test-nextest: ## Run cargo nextest
	$(CARGO) nextest run --no-fail-fast

test-cargo: ## Run cargo tests (workspace)
	$(CARGO) test --workspace --all-targets

test-stable: test-cargo ## Run stable-compatible tests

test-all-features: ## Run tests with all features
	$(CARGO) test --workspace --all-targets --all-features

future-incompat: ## Show Rust future-incompat report
	$(CARGO) report future-incompatibilities

docs-build: ## Build mdBook docs
	$(MDBOOK) build docs

docs-serve: ## Serve mdBook docs
	$(MDBOOK) serve docs

docker-build: ## Build Docker image (DOCKER_TAG=hdp-cairo)
	$(DOCKER) build -t $(DOCKER_TAG) .

docker-run: ## Run Docker image (DOCKER_TAG=hdp-cairo)
	$(DOCKER) run $(DOCKER_RUN_FLAGS) $(DOCKER_TAG) --help

clean: ## Remove build artifacts and caches
	@echo "--- Cleaning: build artifacts, venv, db, and caches ---"
	rm -rf $(CLEAN_DIRS)
	$(UV) cache clean
	$(SCARB) clean
	$(CARGO) clean