# HDP Cairo Syscall Binding

## Overview

This directory contains the Cairo 1 syscall bindings for the HDP framework. It enables simple access to the verified on-chain data from Cairo 1 contracts. These contract are a scarb project. 

## Features

- Perform complex computations on blockchain data
- Access on-chain data from Cairo 1 contracts
- Efficient data retrieval through specialized syscalls

## Installation

To use this package in your Scarb project, add the following to your `Scarb.toml`:

```toml
[dependencies]
hdp_cairo = { git = "https://github.com/your-repo/cairo1_syscall_binding.git" }
```

## Usage
To fetch verified state from HDP, consider the following examples:

### Fetching Account State
```
#[starknet::contract]
mod get_nonce {
    use hdp_cairo::evm::account::AccountTrait;
    use hdp_cairo::{HDP, evm::account::{AccountKey, AccountImpl}};
    use starknet::syscalls::call_contract_syscall;
    use starknet::{ContractAddress, SyscallResult, SyscallResultTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, address: felt252) -> u256 {
        hdp
            .evm
            .account_get_nonce(
                AccountKey { chain_id: 11155111, block_number: block_number.into(), address }
            )
    }
}
```

### Fetching Header State
```cairo
#[starknet::contract]
mod get_gas_limit {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderKey, HeaderImpl}};
    use starknet::syscalls::call_contract_syscall;
    use starknet::{ContractAddress, SyscallResult, SyscallResultTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32) -> u256 {
        hdp
            .evm
            .header_get_gas_limit(HeaderKey { chain_id: 11155111, block_number: block_number.into() })
    }
}
```

### Fetching a Storage Slot
```
#[starknet::contract]
mod get_slot {
    use hdp_cairo::evm::storage::StorageTrait;
    use hdp_cairo::{HDP, evm::storage::{StorageKey, StorageImpl}};
    use starknet::syscalls::call_contract_syscall;
    use starknet::{ContractAddress, SyscallResult, SyscallResultTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(
        ref self: ContractState, hdp: HDP, block_number: u32, address: felt252, storage_slot: u256
    ) -> u256 {
        hdp
            .evm
            .storage_get_slot(
                StorageKey {
                    chain_id: 11155111, block_number: block_number.into(), address, storage_slot
                }
            )
    }
}
```

### Fetching a Block Transaction
```
#[starknet::contract]
mod get_gas_price {
    use hdp_cairo::evm::block_tx::BlockTxTrait;
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxKey, BlockTxImpl}};
    use starknet::syscalls::call_contract_syscall;
    use starknet::{ContractAddress, SyscallResult, SyscallResultTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, index: u32) -> u256 {
        hdp
            .evm
            .block_tx_get_gas_price(BlockTxKey { chain_id: 11155111, block_number: block_number.into(), index: index.into() })
    }
}
```

### Fetching a Block Receipt
```
#[starknet::contract]
mod get_cumulative_gas_used {
    use hdp_cairo::evm::block_receipt::BlockReceiptTrait;
    use hdp_cairo::{HDP, evm::block_receipt::{BlockReceiptKey, BlockReceiptImpl}};
    use starknet::syscalls::call_contract_syscall;
    use starknet::{ContractAddress, SyscallResult, SyscallResultTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, index: u32) -> u256 {
        hdp
            .evm
            .block_receipt_get_cumulative_gas_used(BlockReceiptKey { chain_id: 11155111, block_number: block_number.into(), index: index.into() })
    }
}
```