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
                        chain_id: 11155111, block_number: 7692344, transaction_index: 0,
                    },
                ) == u256 { low: 0x1, high: 0x0 },
        );

        let tx_indexes = array![
            0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0xa, 0xb, 0xc, 0xf,
        ];

        let mut i: usize = 0;
        loop {
            if i >= tx_indexes.len() {
                break;
            }

            hdp
                .evm
                .block_receipt_get_status(
                    BlockReceiptKey {
                        chain_id: 11155111,
                        block_number: 7692344,
                        transaction_index: *tx_indexes.at(i),
                    },
                );

            i += 1;
        };
    }
}

#[starknet::contract]
mod receipts_get_and_tx_get {
    use hdp_cairo::{
        HDP, evm::block_receipt::{BlockReceiptTrait, BlockReceiptKey, BlockReceiptImpl},
        evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl},
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
                        chain_id: 11155111, block_number: 7692344, transaction_index: 0,
                    },
                ) == u256 { low: 0x7f03, high: 0x0 },
        );

        assert!(
            hdp
                .evm
                .block_tx_get_nonce(
                    BlockTxKey { chain_id: 11155111, block_number: 7692344, transaction_index: 0 },
                ) == u256 { low: 0x44c, high: 0x0 },
        );
    }
}
