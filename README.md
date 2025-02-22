# HDP Cairo

HDP (Herodotus Data Processor) is a modular framework for validating on-chain data from multiple blockchain RPC sources, executing user-defined logic written in Cairo1, and producing an execution trace that can be used to generate a zero-knowledge proof. The proof attests to the correctness of both the on-chain data and the performed computation.

<p align="left">
  <a href="https://herodotusdev.github.io/hdp-cairo/program_hash.json">
    <img src="https://img.shields.io/badge/dynamic/json?url=https://herodotusdev.github.io/hdp-cairo/program_hash.json&query=$.program_hash&label=program_hash&color=blue&style=flat-square" alt="program_hash">
  </a>
</p>

## Installation

### Option 1: Install CLI Directly

You can install the CLI using our install script:

```bash
curl -fsSL https://raw.githubusercontent.com/HerodotusDev/hdp-cairo/main/install-cli.sh | bash
```

To install a specific version:

```bash
VERSION=v1.0.4 curl -fsSL https://raw.githubusercontent.com/HerodotusDev/hdp-cairo/main/install-cli.sh | bash
```

### Option 2: Build from Source

To install the required dependencies and set up the Python virtual environment, run:

```bash
make
```

## Running

Before running the program, prepare the input data. The inputs are provided via the [hdp_input.json](examples/hdp_input.json).
Runtime require chain nodes RPC calls, ensure an environment variables [.cargo/config.toml](.cargo/config.example.toml) are set.

### Steps to Execute:

1. **Simulate Cairo1 Module and Collect Proofs Information:**
   ```bash
   hdp-cli dry-run -m examples/hdp_input.json --print_output
   ```
   
   Or when building from source:
   ```bash
   cargo run --release --bin cli -- dry-run -m examples/hdp_input.json --print_output
   ```

2. **Fetch On-Chain Proofs Needed for the HDP Run:**
   ```bash
   hdp-cli fetch-proofs
   ```
   
   Or when building from source:
   ```bash
   cargo run --release --bin cli --features progress_bars -- fetch-proofs
   ```

3. **Run Cairo1 Module with Verified On-Chain Data:**
   ```bash
   hdp-cli sound-run -m examples/hdp_input.json --print_output
   ```
   
   Or when building from source:
   ```bash
   cargo run --release --bin cli -- sound-run -m examples/hdp_input.json --print_output
   ```

The program will output the results root and tasks root. These roots can be used to extract the results from the on-chain contract.

## Testing

Tests require chain nodes RPC calls. Ensure an environment variables [.cargo/config.toml](.cargo/config.example.toml) are set.

1. **Build Cairo1 Modules:**

   ```bash
   scarb build
   ```

2. **Run Tests with [nextest](https://nexte.st/):**
   ```bash
   cargo nextest run
   ```
