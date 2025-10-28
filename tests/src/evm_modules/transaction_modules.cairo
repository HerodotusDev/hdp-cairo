#[starknet::contract]
mod transaction_get_nonce {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_nonce(
                    @BlockTxKey { chain_id: 11155111, block_number: 7692344, transaction_index: 0 },
                ) == u256 { low: 0x44c, high: 0x0 },
        );

        let mut i: usize = 0;
        let max_tx_idx = 10;
        loop {
            if i >= max_tx_idx {
                break;
            }

            let tx_idx = i;
            hdp
                .evm
                .block_tx_get_nonce(
                    @BlockTxKey {
                        chain_id: 11155111, block_number: 7692344, transaction_index: tx_idx.into(),
                    },
                );
            i += 1;
        };
    }
}

#[starknet::contract]
mod transaction_get_gas_price {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_gas_price(
                    @BlockTxKey { chain_id: 11155111, block_number: 7692344, transaction_index: 0 },
                ) == u256 { low: 0x13ca651200, high: 0x0 },
        );
    }
}

#[starknet::contract]
mod transaction_get_gas_limit {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_gas_limit(
                    @BlockTxKey { chain_id: 11155111, block_number: 7692344, transaction_index: 0 },
                ) == u256 { low: 0x8066, high: 0x0 },
        );
    }
}

#[starknet::contract]
mod transaction_get_receiver {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_receiver(
                    @BlockTxKey { chain_id: 11155111, block_number: 7692344, transaction_index: 0 },
                ) == u256 {
                    low: 0x1b27950eF0215CDF5414dDCFc93E8730,
                    high: 0x00000000000000000000000066dA461A,
                },
        );
    }
}

#[starknet::contract]
mod transaction_get_value {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_value(
                    @BlockTxKey { chain_id: 11155111, block_number: 7692344, transaction_index: 0 },
                ) == u256 { low: 0x0, high: 0x0 },
        );
    }
}

#[starknet::contract]
mod transaction_get_v {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_v(
                    @BlockTxKey {
                        chain_id: 11155111, block_number: 7692344, transaction_index: 14,
                    },
                ) == u256 { low: 0x1, high: 0x0 },
        );
    }
}

#[starknet::contract]
mod transaction_get_r {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_r(
                    @BlockTxKey { chain_id: 11155111, block_number: 7692344, transaction_index: 0 },
                ) == u256 {
                    low: 0x3330f4d401e28a15eca335e36aae0f6d,
                    high: 0xab351c4e42fa9fa986ff8dff111098c6,
                },
        );
    }
}

#[starknet::contract]
mod transaction_get_s {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_s(
                    @BlockTxKey { chain_id: 11155111, block_number: 7692344, transaction_index: 0 },
                ) == u256 {
                    low: 0x7013fd6e83d6662112aa5213b160b991,
                    high: 0x70d642f2986d9dad3c76e18a256894cd,
                },
        );
    }
}

#[starknet::contract]
mod transaction_get_chain_id {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_chain_id(
                    @BlockTxKey {
                        chain_id: 11155111, block_number: 7692344, transaction_index: 14,
                    },
                ) == u256 { low: 0xaa36a7, high: 0x0 },
        );
    }
}

// TODO: uncomment when the indexer is able to resolve the tx
// #[starknet::contract]
// mod transaction_get_max_fee_per_gas {
//     use hdp_cairo::{HDP, evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl}};

//     #[storage]
//     struct Storage {}

//     #[external(v0)]
//     pub fn main(ref self: ContractState, hdp: HDP) {
//         assert!(
//             hdp
//                 .evm
//                 .block_tx_get_max_fee_per_gas(
//                     @BlockTxKey {
//                         chain_id: 11155111, block_number: 5382809, transaction_index: 217,
//                     },
//                 ) == u256 { low: 0x5f5e100, high: 0x0 },
//         );
//     }
// }

// TODO: uncomment when the indexer is able to resolve the tx
// #[starknet::contract]
// mod transaction_get_max_priority_fee_per_gas {
//     use hdp_cairo::{HDP, evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl}};

//     #[storage]
//     struct Storage {}

//     #[external(v0)]
//     pub fn main(ref self: ContractState, hdp: HDP) {
//         assert!(
//             hdp
//                 .evm
//                 .block_tx_get_max_priority_fee_per_gas(
//                     @BlockTxKey {
//                         chain_id: 11155111, block_number: 5382809, transaction_index: 217,
//                     },
//                 ) == u256 { low: 0x186a0, high: 0x0 },
//         );
//     }
// }


// // Testing EIP-4844 transaction max fee per blob gas
// #[starknet::contract]
// mod transaction_get_max_fee_per_blob_gas {
//     use hdp_cairo::{HDP, evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl}};

//     #[storage]
//     struct Storage {}

//     #[external(v0)]
//     pub fn main(ref self: ContractState, hdp: HDP) {
//         assert!(
//             hdp
//                 .evm
//                 .block_tx_get_max_fee_per_blob_gas(
//                     @BlockTxKey {
//                         chain_id: 11155111, block_number: 9410665, transaction_index: 3,
//                     },
//                 ) == u256 { low: 0x3, high: 0x0 },
//         );
//     }
// }

// Legacy transaction decoding test
#[starknet::contract]
mod transaction_get_tx_type_legacy {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_tx_type(
                    @BlockTxKey { chain_id: 11155111, block_number: 7692344, transaction_index: 0 },
                ) == u256 { low: 0x0, high: 0x0 },
        );
    }
}

// EIP-2930 transaction decoding test
#[starknet::contract]
mod transaction_get_tx_type_eip2930 {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_tx_type(
                    @BlockTxKey { chain_id: 11155111, block_number: 7354022, transaction_index: 2 },
                ) == u256 { low: 0x1, high: 0x0 },
        );
    }
}

// EIP-1559 transaction decoding test
#[starknet::contract]
mod transaction_get_tx_type_eip2559 {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_tx_type(
                    @BlockTxKey { chain_id: 11155111, block_number: 6005662, transaction_index: 82 },
                ) == u256 { low: 0x2, high: 0x0 },
        );
    }
}

// EIP-4844 transaction decoding test
#[starknet::contract]
mod transaction_get_tx_type_eip4844 {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_tx_type(
                    @BlockTxKey { chain_id: 11155111, block_number: 9410665, transaction_index: 3 },
                ) == u256 { low: 0x3, high: 0x0 },
        );
    }
}

// EIP-7702 transaction decoding test
#[starknet::contract]
mod transaction_get_tx_type_eip7702 {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_tx_type(
                    @BlockTxKey { chain_id: 11155111, block_number: 8179046, transaction_index: 252 },
                ) == u256 { low: 0x4, high: 0x0 },
        );
    }
}

#[starknet::contract]
mod transaction_get_sender {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_sender(
                    @BlockTxKey { chain_id: 11155111, block_number: 7692344, transaction_index: 0 },
                ) == u256 {
                    low: 0x7073DDdA4Fc7FA9C215d32DeA90e6af0,
                    high: 0x000000000000000000000000401bF248,
                },
        );
    }
}

#[starknet::contract]
mod transaction_get_hash {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_hash(
                    @BlockTxKey { chain_id: 11155111, block_number: 7692344, transaction_index: 0 },
                ) == u256 {
                    low: 0xd5b6d3bd82871adf40781ac3b842322,
                    high: 0x7af28779b0b27c15572d5e425d0f4cef,
                },
        );
    }
}

