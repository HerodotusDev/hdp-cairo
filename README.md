# HDP Cairo

HDP (Herodotus Data Processor) validates on-chain data across multiple chains, runs user-defined Cairo1 logic, and
produces an execution trace suitable for zero-knowledge proofs.

<p align="center">
  <img src="./docs/HDPCairo.png" alt="HDP Cairo">
</p>

<p align="left">
  <a href="https://herodotusdev.github.io/hdp-cairo/program_hash.json">
    <img src="https://img.shields.io/badge/dynamic/json?url=https://herodotusdev.github.io/hdp-cairo/program_hash.json&query=$.program_hash&label=program_hash&color=blue&style=flat-square" alt="program_hash">
  </a>
</p>

## Quick start (CLI)

```sh
curl -fsSL https://raw.githubusercontent.com/HerodotusDev/hdp-cairo/main/install-cli.sh | bash
hdp env-info
hdp dry-run -m module_contract_class.json --print_output
hdp fetch-proofs
hdp sound-run -m module_contract_class.json --print_output
```

`module_contract_class.json` is produced by a Scarb build of your Cairo1 module.

## Prerequisites

- **Rust toolchain**: pinned to `nightly-2025-04-06` via `rust-toolchain.toml`.
  `rustup` will install it automatically, or run:
  ```sh
  rustup toolchain install nightly-2025-04-06
  ```
- **uv**: Python package manager used to install Cairo0 tooling.
  ```sh
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ```

## Installation

### Option 1: CLI tool (recommended)

```sh
curl -fsSL https://raw.githubusercontent.com/HerodotusDev/hdp-cairo/main/install-cli.sh | bash
```

To install a specific version:

```sh
VERSION=vX.X.X curl -fsSL https://raw.githubusercontent.com/HerodotusDev/hdp-cairo/main/install-cli.sh | bash
```

### Option 2: Build from source

1. Clone and init submodules:
   ```sh
   git clone https://github.com/HerodotusDev/hdp-cairo.git
   cd hdp-cairo
   git submodule update --init
   ```
2. Install Python deps and Cairo0 tooling:
   ```sh
   uv sync
   ```
3. Build the CLI:
   ```sh
   cargo build --release --bin hdp-cli
   ```

To use `cairo-format` from the virtual environment:

```sh
source .venv/bin/activate
```

## Toolchain and features

- **Default**: builds with the pinned nightly toolchain.
- **STWO prover input**: build with `--features stwo`.

```sh
cargo build --release --bin hdp-cli --features stwo
```

If you run `hdp sound-run --stwo_prover_input ...` without `--features stwo`, the CLI will instruct you to rebuild.

## Runtime configuration

The runtime requires RPC access. Use the CLI helpers or copy the example env file:

```sh
hdp env-info
hdp env-check --inputs dry_run_output.json
cp example.env .env
```

RPC variables (see `example.env`):

- `RPC_URL_HERODOTUS_INDEXER`
- `RPC_URL_ETHEREUM_MAINNET`
- `RPC_URL_ETHEREUM_TESTNET`
- `RPC_URL_STARKNET_MAINNET`
- `RPC_URL_STARKNET_TESTNET`
- `RPC_URL_OPTIMISM_MAINNET`
- `RPC_URL_OPTIMISM_TESTNET`

`hdp fetch-proofs` reads the dry-run output and fails fast with the missing variables for the chains used in that run.

## Workflow

1. **Dry run**: simulate the module and collect proof requirements.
   ```sh
   hdp dry-run -m module_contract_class.json --print_output
   ```
2. **Fetch proofs**:
   ```sh
   hdp fetch-proofs
   ```
3. **Sound run**: execute the module with verified data.
   ```sh
   hdp sound-run -m module_contract_class.json --print_output
   ```

For source builds, use `cargo run --release --bin hdp-cli -- <command>`.

## Documentation

- `docs/` contains the mdBook sources.
- Cairo library details live under `docs/src/cairo_library/`.

## Development and testing

```sh
cargo test
```

Optional:

```sh
scarb build
cargo nextest run
```

To enable integration-heavy tests:

```sh
HDP_INTEGRATION_TESTS=1 cargo test
```

If you see future-incompatible warnings (e.g. `size-of`), inspect with:

```sh
make future-incompat
```

## Note on on-chain finality

Even if local stages (dry run, proof fetching, sound run) succeed, on-chain settlement depends on **MMRs (Merkle
Mountain Ranges)**. Blocks accessed must be included in the MMRs within the
[Herodotus Satellite contracts](https://github.com/HerodotusDev/satellite).

## Mentions

Provable ETH call (in `hdp_cairo/src/eth_call/`) adapts code from
[Kakarot](https://github.com/kkrt-labs) ([kkrt-labs/kakarot-ssj](https://github.com/kkrt-labs/kakarot-ssj))
under the [MIT License](https://github.com/kkrt-labs/kakarot-ssj/blob/main/LICENSE).

## License

`hdp-cairo` is licensed under the [Apache-2.0 license](./LICENSE).
