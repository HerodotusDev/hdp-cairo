# HDP Cairo

HDP (Herodotus Data Processor) is a modular framework for validating on-chain data from multiple blockchain RPC sources, executing user-defined logic written in Cairo1, and producing an execution trace that can be used to generate a zero-knowledge proof. The proof attests to the correctness of both the on-chain data and the performed computation.

## Installation and Setup

To install the required dependencies and set up the Python virtual environment, run:

```bash
make
```

## Running

Before running the program, prepare the input data. The inputs are provided via the [hdp_input.json](examples/hdp_input.json).
Runtime require chain nodes RPC calls, ensure an environment variables [.env.example](.env.example) are set.

### Steps to Execute:

1. **Simulate Cairo1 Module and Collect Proofs Information:**
   ```bash
   cargo run --release --bin dry_run -- --program_input examples/hdp_input.json --program_output hdp_keys.json --layout starknet_with_keccak
   ```

2. **Fetch On-Chain Proofs Needed for the HDP Run:**
   ```bash
   cargo run --release --bin fetcher --features progress_bars -- hdp_keys.json --program_output hdp_proofs.json
   ```

3. **Run Cairo1 Module with Verified On-Chain Data:**
   ```bash
   cargo run --release --bin sound_run -- --program_input examples/hdp_input.json --program_proofs hdp_proofs.json --print_output --layout starknet_with_keccak --cairo_pie_output pie.zip
   ```

The program will output the results root and tasks root. These roots can be used to extract the results from the on-chain contract.

## Testing

Tests require chain nodes RPC calls. Ensure an environment variables [.env.example](.env.example) are set.

1. **Build Cairo1 Modules:**
   ```bash
   scarb build
   ```

2. **Run Tests with [nextest](https://nexte.st/):**
   ```bash
   cargo nextest run
   ```

