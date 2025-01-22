# HDP Cairo

Cairo HDP is a collection of Cairo0 programs designed to verify inclusion proofs and perform computations on the data. These computations can be verified on-chain, enabling trustless operations on any historical data from Ethereum or integrated EVM chains.

## Installation and Setup

To install the required dependencies and set up the Python virtual environment, run:

```bash
make setup
```

Ensure you run the Cairo program from the virtual environment. To activate the virtual environment, execute:

```bash
source venv/bin/activate
```

## Running

Before running the program, prepare the input data. The inputs are provided via the `hdp_input.json` file located in the root directory of the HDP project.

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

## How It Works

HDP Cairo is the repository containing the logic for verifying on-chain state via storage proofs and making that state available to custom Cairo1 contract modules. To enable this functionality, a custom syscall was designed, enabling dynamic access to the verified state. The syscalls are defined in `cairo1`, where examples are provided.

### Architecture

The overall program is split into two main parts:

1. **Storage Proof Verification**
   - In the first stage, we verify the storage proofs found in the `hdp_input.json` file. This file contains all the storage proofs for the state required by the contract's execution.
   - The `hdp_input.json` file is generated during the Dry Run stage, where execution is mocked, and the state accessed by the contract is extracted.
   - Once this stage is complete, all the verified state is stored in memorizers, enabling it to be queried via syscall.

2. **Bootloading**
   - In this stage, we bootload the Cairo1 contract.
   - The contract's bytecode is read from the `hdp_input.json` file and executed in the HDP bootloader.
   - The bootloader processes the bytecode and invokes the contained syscalls, which fetch and decode the requested state from the memorizers, loading it into the contract's memory.
   - This setup allows seamless access to verified on-chain state within contracts.

## Testing

Some tests require chain nodes RPC calls. Ensure an environment variable named `ETH_RPC` and `STARKNET_RPC` is set.

1. **Build Cairo1 Modules:**
   ```bash
   scarb build
   ```

2. **Run Tests with [nextest](https://nexte.st/):**
   ```bash
   cargo nextest run
   ```

