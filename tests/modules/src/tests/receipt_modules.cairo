#[starknet::contract]
mod receipts_get_status {
    use hdp_cairo::{
        HDP, evm::block_receipt::{BlockReceiptTrait, BlockReceiptKey, BlockReceiptImpl},
    };

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_receipt_get_status(
                    BlockReceiptKey {
                        chain_id: 11155111, block_number: 5382809, transaction_index: 217,
                    },
                ) == u256 { low: 0x1, high: 0x0 },
        );
    }
}

#[starknet::contract]
mod receipts_get_cumulative_gas_used {
    use hdp_cairo::{
        HDP, evm::block_receipt::{BlockReceiptTrait, BlockReceiptKey, BlockReceiptImpl},
    };

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_receipt_get_cumulative_gas_used(
                    BlockReceiptKey {
                        chain_id: 11155111, block_number: 5382809, transaction_index: 217,
                    },
                ) == u256 { low: 0x1a4bd13, high: 0x0 },
        );
    }
}
