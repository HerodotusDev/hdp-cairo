#[starknet::contract]
mod receipts_get_status {
    use hdp_cairo::{
        HDP, evm::block_receipt::{BlockReceiptImpl, BlockReceiptKey, BlockReceiptTrait},
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
        HDP, evm::block_receipt::{BlockReceiptImpl, BlockReceiptKey, BlockReceiptTrait},
        evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait},
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

#[starknet::contract]
mod receipts_get_address {
    use hdp_cairo::{
        HDP, evm::block_receipt::{BlockReceiptImpl, BlockReceiptKey, BlockReceiptTrait},
    };

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_receipt_get_address(
                    BlockReceiptKey {
                        chain_id: 11155111, block_number: 7692344, transaction_index: 180,
                    },
                ) == u256 { low: 0xE1A608bcc77C2d392093cE7F05c0DB14, high: 0x7Eaa8557 },
        );
    }
}

#[starknet::contract]
mod receipts_get_topic0 {
    use hdp_cairo::{
        HDP, evm::block_receipt::{BlockReceiptImpl, BlockReceiptKey, BlockReceiptTrait},
    };

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_receipt_get_topic0(
                    BlockReceiptKey {
                        chain_id: 11155111, block_number: 7692344, transaction_index: 180,
                    },
                ) == u256 {
                    low: 0xdd0314c0f7b2291e5b200ac8c7c3b925,
                    high: 0x8c5be1e5ebec7d5bd14f71427d1e84f3,
                },
        );
    }
}

#[starknet::contract]
mod receipts_get_topic1 {
    use hdp_cairo::{
        HDP, evm::block_receipt::{BlockReceiptImpl, BlockReceiptKey, BlockReceiptTrait},
    };

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_receipt_get_topic1(
                    BlockReceiptKey {
                        chain_id: 11155111, block_number: 7692344, transaction_index: 180,
                    },
                ) == u256 { low: 0xc2eD6f12bF99dAb43C55f40d7D40b730, high: 0xfB41B2F3 },
        );
    }
}

#[starknet::contract]
mod receipts_get_topic2 {
    use hdp_cairo::{
        HDP, evm::block_receipt::{BlockReceiptImpl, BlockReceiptKey, BlockReceiptTrait},
    };

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_receipt_get_topic2(
                    BlockReceiptKey {
                        chain_id: 11155111, block_number: 7692344, transaction_index: 180,
                    },
                ) == u256 { low: 0x798deddCAf5EB9264a3b8D1D7c4f09d7, high: 0x421c3ab6 },
        );
    }
}

#[starknet::contract]
mod receipts_get_data {
    use hdp_cairo::{
        HDP, evm::block_receipt::{BlockReceiptImpl, BlockReceiptKey, BlockReceiptTrait},
    };

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        let mut data = hdp.evm.block_receipt_get_data(
            BlockReceiptKey {
                chain_id: 11155111, block_number: 7692344, transaction_index: 180,
            }
        );

        assert!(
            Serde::deserialize(ref data).unwrap() == u256 { low: 0xde0b6b3a7640000, high: 0x0 },
        );
    }
}
