## Installation and Setup

### Prerequisites

- **Dependencies:**
  - Rust (latest stable version)
  - Python (for virtual environment setup)
- **System Requirements:**
  - Access to blockchain RPC endpoints (Ethereum, StarkNet, etc.)

### Installation Steps

1. **Clone the Repository:**

   ```bash
   git clone https://github.com/HerodotusDev/hdp-cairo.git
   cd hdp-cairo
   ```

2. **Set Up the Environment:**
   Install cairo0 toolchain.
   Create and activate a Python virtual environment:

   ```bash
   make
   ```

3. **Configuration:**
   Set the required environment variables by copying the example configuration:
   ```bash
   cp .env.example .env
   ```
   Edit the `.env` file with the correct RPC endpoints and other configuration details.

---

## Running an Example Contract

### Overview

This section describes how to run an example Cairo1 module, which demonstrates the complete HDP workflow from data fetching to execution and proof generation.

### Execution Processes

#### Dry Run Process

- **Purpose:**  
  Analyze the Cairo1 module to identify which on-chain data and proofs are needed.
- **Command:**
  ```bash
  cargo run --release --bin dry_run -- --program_input examples/hdp_input.json --program_output hdp_keys.json --layout starknet_with_keccak
  ```

#### Fetcher Process

- **Purpose:**  
  Connect to the blockchain RPC endpoints to fetch the on-chain data and the corresponding proofs, based on the keys identified during the dry run.

- **Command:**
  ```bash
  cargo run --release --bin fetcher --features progress_bars -- hdp_keys.json --program_output hdp_proofs.json
  ```

#### Sound Run Process

- **Purpose:**  
  Execute the compiled Cairo1 bytecode with the verified data. During this process, the bootloader retrieves data from the memorizers, handles system calls, and runs the user logic. Upon completion, the execution trace is generated.

- **Command:**
  ```bash
  cargo run --release --bin sound_run -- --program_input examples/hdp_input.json --program_proofs hdp_proofs.json --print_output --layout starknet_with_keccak --cairo_pie_output pie.zip
  ```

---

## Testing

Testing involves running the full HDP pipeline with live RPC calls to ensure that each component works as expected.

1. **Build Cairo1 Modules:**

   ```bash
   scarb build
   ```

2. **Run Tests Using Nextest:**
   ```bash
   cargo nextest run
   ```

_Note:_ Ensure the environment variables from `.env.example` are set before running tests.
