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

        let tx_indexes = array![
            0x0, // First tx in block
            0x1, // Single byte indexes
            0x2,
            0x3,
            0x4,
            0x5,
            0x6,
            0x7,
            0x8,
            0x9,
            0xa,
            0xb,
            0xc,
            0xf,
            0x3f, // huge tx, pls keep
            0xc0,
            0xd0,
            0xe0,
            0xe9,
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
                        block_number: 5382809,
                        transaction_index: *tx_indexes.at(i),
                    },
                );

            i += 1;
        };
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
