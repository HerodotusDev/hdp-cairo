# Getting Started

This guide gets you from zero to a full HDP pipeline run in about 10 minutes.

## Prerequisites

- Rust (stable) and Cargo
- Scarb (Cairo toolchain)
- `uv` (Python package manager for Cairo tooling)
- RPC endpoints for the chains you will query

Optional:

- Docker (for containerized builds)
- Nightly Rust if you plan to generate STWO prover input

## Installation

### Option 1: Install the CLI (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/HerodotusDev/hdp-cairo/main/install-cli.sh | bash
```

The installer builds `hdp-cli` and creates a `hdp` symlink in `$HOME/.local/bin`.

Install a specific version:

```bash
VERSION=vX.X.X curl -fsSL https://raw.githubusercontent.com/HerodotusDev/hdp-cairo/main/install-cli.sh | bash
```

### Option 2: Build from source

```bash
git clone https://github.com/HerodotusDev/hdp-cairo.git
cd hdp-cairo
git submodule update --init
uv sync
source .venv/bin/activate
```

### Makefile shortcuts (optional)

If you prefer make targets:

```bash
make setup   # uv sync + cargo check
make build   # scarb build + cargo build --release
make test    # scarb build -p tests + cargo nextest run
```

### Option 3: Docker (optional)

The Docker image installs the CLI from `crates/cli` and sets `hdp-cli` as the entrypoint.

```bash
docker build -t hdp-cairo .
docker run --rm -it hdp-cairo --help
```

## Environment setup

Copy the example env file and fill in RPC endpoints:

```bash
cp example.env .env
```

Useful CLI helpers:

- `hdp env-info` prints the expected env vars and example values.
- `hdp env-check --inputs dry_run_output.json` checks which RPCs are required.

## First run (StarkGate example)

The `examples/starkgate` project demonstrates a full pipeline. Build the Cairo module first:

```bash
cd examples/starkgate
scarb build
```

Run the pipeline using the installed `hdp` binary:

```bash
hdp dry-run -m target/dev/example_starkgate_module.compiled_contract_class.json --print_output
hdp fetch-proofs
hdp sound-run -m target/dev/example_starkgate_module.compiled_contract_class.json --print_output
```

If you built from source, you can run the binaries directly:

```bash
cargo run --release --bin dry_run -- -m target/dev/example_starkgate_module.compiled_contract_class.json --print_output
cargo run --bin fetcher
cargo run --release --bin sound_run -- -m target/dev/example_starkgate_module.compiled_contract_class.json --print_output
```

## What to expect

- `dry_run_output.json` is produced after Stage 1 and contains the key set.
- `proofs.json` is produced after Stage 2 and contains cryptographic proofs.
- Stage 3 prints `task_hash`, `output_root`, and `mmr_metas`.

## CLI quick reference

- `hdp dry-run`: simulate and collect keys
- `hdp fetch-proofs`: fetch MMR/MPT proofs
- `hdp sound-run`: verify and execute offline
- `hdp env-info`: print required env vars
- `hdp env-check --inputs dry_run_output.json`: validate RPC config

## Tests

```bash
scarb build
cargo nextest run
```

Make sure `.env` is configured before running tests.
