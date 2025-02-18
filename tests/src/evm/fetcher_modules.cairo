#[starknet::contract]
mod evm_fetcher_many_keys_same_header {
    use hdp_cairo::{
        HDP, evm::account::{AccountImpl, AccountKey, AccountTrait},
        evm::block_receipt::{BlockReceiptImpl, BlockReceiptKey, BlockReceiptTrait},
        evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait},
        evm::header::{HeaderImpl, HeaderKey, HeaderTrait},
        evm::storage::{StorageImpl, StorageKey, StorageTrait},
    };

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        // Header
        hdp.evm.header_get_parent(HeaderKey { chain_id: 11155111, block_number: 7692344 });
        // Account
        hdp
            .evm
            .account_get_nonce(
                AccountKey {
                    chain_id: 11155111,
                    block_number: 7692344,
                    address: 0xc6e2459991BfE27cca6d86722F35da23A1E4Cb97,
                },
            );
        // Storage
        hdp
            .evm
            .storage_get_slot(
                StorageKey {
                    chain_id: 11155111,
                    block_number: 7692344,
                    address: 0x75cec1db9dceb703200eaa6595f66885c962b920,
                    storage_slot: 0x1,
                },
            );
        // Transaction
        hdp
            .evm
            .block_tx_get_nonce(
                BlockTxKey { chain_id: 11155111, block_number: 7692344, transaction_index: 0 },
            );
        // Receipt
        hdp
            .evm
            .block_receipt_get_cumulative_gas_used(
                BlockReceiptKey { chain_id: 11155111, block_number: 7692344, transaction_index: 1 },
            );
    }
}

#[starknet::contract]
mod evm_fetcher_many_keys_same_header_10x {
    use hdp_cairo::{
        HDP, evm::account::{AccountImpl, AccountKey, AccountTrait},
        evm::header::{HeaderImpl, HeaderKey, HeaderTrait},
        evm::storage::{StorageImpl, StorageKey, StorageTrait},
    };

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        for i in 0..10_u256 {
            let block_number: felt252 = (7692344 - i).try_into().unwrap();
            // Header
            hdp.evm.header_get_parent(HeaderKey { chain_id: 11155111, block_number });
            // Account
            hdp
                .evm
                .account_get_nonce(
                    AccountKey {
                        chain_id: 11155111,
                        block_number,
                        address: 0xc6e2459991BfE27cca6d86722F35da23A1E4Cb97,
                    },
                );
            // Storage
            hdp
                .evm
                .storage_get_slot(
                    StorageKey {
                        chain_id: 11155111,
                        block_number,
                        address: 0x75cec1db9dceb703200eaa6595f66885c962b920,
                        storage_slot: 0x1,
                    },
                );
        }
    }
}

#[starknet::contract]
mod evm_fetcher_many_txns_same_header {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        let block_number: felt252 = 7692344;
        for i in 0..10_u256 {
            let transaction_index: felt252 = i.try_into().unwrap();
            // Transaction
            hdp
                .evm
                .block_tx_get_nonce(
                    BlockTxKey { chain_id: 11155111, block_number, transaction_index },
                );
        }
    }
}

