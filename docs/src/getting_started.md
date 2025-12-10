## Installation and Setup

### Option 1: Using CLI Tool (Recommended)

1. **Install the CLI:**

   ```bash
   curl -fsSL https://raw.githubusercontent.com/HerodotusDev/hdp-cairo/main/install-cli.sh | bash
   ```

   To install a specific version:

   ```bash
   VERSION=vX.X.X curl -fsSL https://raw.githubusercontent.com/HerodotusDev/hdp-cairo/main/install-cli.sh | bash
   ```

2. **ENVs:**
   HDP CLI requires and RPC endpoint for Ethereum and Starknet.
   Please expose env vars before running present in [.env](https://github.com/HerodotusDev/hdp-cairo/blob/main/example.env)

### Option 2: Building from Source

- **Dependencies:**
  - **Rust**.
  - **Python:** For Cairo0 compiler.
- **Requirements:**
  - Access to blockchain RPC endpoints (e.g., Ethereum, StarkNet).

### Installation Steps

1. **Clone the Repository:**

   ```bash
   git clone https://github.com/HerodotusDev/hdp-cairo.git
   cd hdp-cairo
   ```

2. **Set Up the Environment:**

   - Install the `cairo0` toolchain.

     ```bash
     make
     ```

3. **Configuration:**

   - Copy the example environment file:

     ```bash
     cp example.env .env
     ```

   - Edit the [.env](https://github.com/HerodotusDev/hdp-cairo/blob/main/example.env) file to provide the correct RPC endpoints and configuration details.

---

## Running an Example Module

### Overview

This guide demonstrates how to run an example Cairo1 module that verifies StarkGate solvency by comparing token supplies on Ethereum (L1) and StarkNet (L2).

### Example Module: StarkGate Solvency Check

The following code compares the total token supply on both chains:

```rust,ignore
#[starknet::contract]
mod example_starkgate {
    use hdp_cairo::HDP;
    use hdp_cairo::evm::{account::{AccountKey, AccountImpl}, ETHEREUM_TESTNET_CHAIN_ID};
    use hdp_cairo::starknet::{storage::{StorageKey, StorageImpl}, STARKNET_TESTNET_CHAIN_ID};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> u128 {
        // Define the L1 Ethereum bridge account key.
        // More details: https://github.com/starknet-io/starknet-addresses/blob/master/bridged_tokens/sepolia.json#L2-L10
        let starkgate_evm_account_key = AccountKey {
            chain_id: ETHEREUM_TESTNET_CHAIN_ID,
            block_number: 7692344,
            address: 0x8453FC6Cd1bCfE8D4dFC069C400B433054d47bDc, // l1_bridge_address
        };

        // Define the L2 StarkNet token storage key (ERC20 total supply).
        let starkgate_starknet_storage_key = StorageKey {
            chain_id: STARKNET_TESTNET_CHAIN_ID,
            block_number: 517902,
            address: 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7, // l2_token_address
            storage_slot: 0x0110e2f729c9c2b988559994a3daccd838cf52faf88e18101373e67dd061455a, // ERC20 totalSupply slot
        };

        // Retrieve the Ethereum balance for the L1 bridge account.
        let starkgate_balance_ethereum: u256 = hdp.evm.account_get_balance(starkgate_evm_account_key);

        // Ensure the balance is within 128 bits.
        assert!(starkgate_balance_ethereum.high == 0x0);

        // Retrieve the StarkNet token total supply.
        let starkgate_balance_starknet: u128 = hdp
            .starknet
            .storage_get_slot(starkgate_starknet_storage_key)
            .try_into()
            .unwrap();

        // Define an acceptable accuracy range (0.1% of the Ethereum balance).
        let starkgate_balance_ethereum_accuracy: u128 = starkgate_balance_ethereum.low / 1000;

        // Validate that the StarkNet balance is within the acceptable range of the Ethereum balance.
        assert!(
            starkgate_balance_ethereum.low + starkgate_balance_ethereum_accuracy > starkgate_balance_starknet,
        );
        assert!(
            starkgate_balance_ethereum.low - starkgate_balance_ethereum_accuracy < starkgate_balance_starknet,
        );

        println!("StarkGate balance {}", starkgate_balance_ethereum.low);

        // Return the Ethereum balance (low part).
        starkgate_balance_ethereum.low
    }
}
```

### Running the Pipeline

You can run the pipeline either using the CLI tool or building from source.

#### Build the Cairo1 Modules

```bash
scarb build
```

#### Using CLI Tool

1. **Dry Run Process:**

- **Purpose:**  
  Identify the required on-chain data and proofs.
- **Command:**
  ```bash
  hdp dry-run -m target/dev/example_starkgate_module.compiled_contract_class.json --print_output
  ```

2. **Fetcher Process:**

- **Purpose:**  
  Connect to blockchain RPC endpoints to fetch on-chain data and corresponding proofs, using the keys identified during the dry run.
- **Command:**
  ```bash
  hdp fetch-proofs
  ```

3. **Sound Run Process:**

- **Purpose:**  
  Execute the compiled Cairo1 bytecode with the verified data. During this process, the bootloader retrieves data, handles system calls, and runs user logic, generating an execution trace.
- **Command:**
  ```bash
  hdp sound-run -m target/dev/example_starkgate_module.compiled_contract_class.json --print_output
  ```

#### Using Source Build

1. **Dry Run Process:**

- **Purpose:**  
  Identify the required on-chain data and proofs.
- **Command:**
  ```bash
  cargo run --release --bin hdp-cli -- dry-run -m target/dev/example_starkgate_module.compiled_contract_class.json --print_output
  ```

2. **Fetcher Process:**

- **Purpose:**  
  Connect to blockchain RPC endpoints to fetch on-chain data and corresponding proofs, using the keys identified during the dry run.
- **Command:**
  ```bash
  cargo run --release --bin hdp-cli --features progress_bars -- fetch-proofs
  ```

3. **Sound Run Process:**

- **Purpose:**  
  Execute the compiled Cairo1 bytecode with the verified data. During this process, the bootloader retrieves data, handles system calls, and runs user logic, generating an execution trace.
- **Command:**
  ```bash
  cargo run --release --bin hdp-cli -- sound-run -m target/dev/example_starkgate_module.compiled_contract_class.json --print_output
  ```

---

## Testing

1. **Build the Cairo1 Modules:**

   ```bash
   scarb build
   ```

2. **Run Tests with Nextest:**

   ```bash
   cargo nextest run
   ```

> **Note:** Ensure that the environment variables from [.env](https://github.com/HerodotusDev/hdp-cairo/blob/main/example.env) are set before running the tests.
