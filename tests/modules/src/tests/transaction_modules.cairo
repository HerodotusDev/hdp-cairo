#[starknet::contract]
mod transaction_get_nonce {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_nonce(
                    BlockTxKey {
                        chain_id: 11155111, block_number: 5382809, transaction_index: 217,
                    },
                ) == u256 { low: 0x3, high: 0x0 },
        );
    }
}

// TODO: find a tx w/ gas price
// #[starknet::contract]
// mod transaction_get_gas_price {
//     use hdp_cairo::{HDP, evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl}};

//     #[storage]
//     struct Storage {}

//     #[external(v0)]
//     pub fn main(ref self: ContractState, hdp: HDP) {
//         assert!(
//             hdp
//                 .evm
//                 .block_tx_get_gas_price(
//                     BlockTxKey {
//                         chain_id: 11155111, block_number: 5382809, transaction_index: 217,
//                     },
//                 ) == u256 { low: 0x1a48b6b, high: 0x0 },
//         );
//     }
// }

#[starknet::contract]
mod transaction_get_gas_limit {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_gas_limit(
                    BlockTxKey {
                        chain_id: 11155111, block_number: 5382809, transaction_index: 217,
                    },
                ) == u256 { low: 0x30d40, high: 0x0 },
        );
    }
}

#[starknet::contract]
mod transaction_get_receiver {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_receiver(
                    BlockTxKey {
                        chain_id: 11155111, block_number: 5382809, transaction_index: 217,
                    },
                ) == u256 { low: 0xf0ab037fe771fc36d39c1e19bcc0fdb5, high: 0x7a4ee6f9 },
        );
    }
}

#[starknet::contract]
mod transaction_get_value {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_value(
                    BlockTxKey {
                        chain_id: 11155111, block_number: 5382809, transaction_index: 217,
                    },
                ) == u256 { low: 0x0, high: 0x0 },
        );
    }
}

#[starknet::contract]
mod transaction_get_v {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_v(
                    BlockTxKey {
                        chain_id: 11155111, block_number: 5382809, transaction_index: 217,
                    },
                ) == u256 { low: 0x0, high: 0x0 },
        );
    }
}

#[starknet::contract]
mod transaction_get_r {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_r(
                    BlockTxKey {
                        chain_id: 11155111, block_number: 5382809, transaction_index: 217,
                    },
                ) == u256 {
                    low: 0xa81dea211de2ece189bf6d4ab2a6ad92,
                    high: 0x1c110385b6b091253b50a924d37194c9,
                },
        );
    }
}

#[starknet::contract]
mod transaction_get_s {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_s(
                    BlockTxKey {
                        chain_id: 11155111, block_number: 5382809, transaction_index: 217,
                    },
                ) == u256 {
                    low: 0x3c55c500af8e549833123c1e46f82aa2,
                    high: 0x20312b6d21359afdb5877dac42d0632,
                },
        );
    }
}

#[starknet::contract]
mod transaction_get_chain_id {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_chain_id(
                    BlockTxKey {
                        chain_id: 11155111, block_number: 5382809, transaction_index: 217,
                    },
                ) == u256 { low: 0xaa36a7, high: 0x0 },
        );
    }
}

#[starknet::contract]
mod transaction_get_max_fee_per_gas {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_max_fee_per_gas(
                    BlockTxKey {
                        chain_id: 11155111, block_number: 5382809, transaction_index: 217,
                    },
                ) == u256 { low: 0x5f5e100, high: 0x0 },
        );
    }
}

#[starknet::contract]
mod transaction_get_max_priority_fee_per_gas {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_max_priority_fee_per_gas(
                    BlockTxKey {
                        chain_id: 11155111, block_number: 5382809, transaction_index: 217,
                    },
                ) == u256 { low: 0x186a0, high: 0x0 },
        );
    }
}

// TODO: find a tx w/ blob gas
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
//                     BlockTxKey {
//                         chain_id: 11155111, block_number: 5382809, transaction_index: 217,
//                     },
//                 ) == u256 { low: 0x3, high: 0x0 },
//         );
//     }
// }

#[starknet::contract]
mod transaction_get_tx_type {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_tx_type(
                    BlockTxKey {
                        chain_id: 11155111, block_number: 5382809, transaction_index: 217,
                    },
                ) == u256 { low: 0x2, high: 0x0 },
        );
    }
}

#[starknet::contract]
mod transaction_get_sender {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_sender(
                    BlockTxKey {
                        chain_id: 11155111, block_number: 5382809, transaction_index: 217,
                    },
                ) == u256 { low: 0x5f51129cf2ae0c175535460fe055267e, high: 0xc369705f },
        );
    }
}

#[starknet::contract]
mod transaction_get_hash {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_hash(
                    BlockTxKey {
                        chain_id: 11155111, block_number: 5382809, transaction_index: 217,
                    },
                ) == u256 {
                    low: 0x88b3e55ed30c8d9894f8a8657798802a,
                    high: 0xb1df739d499c7dfae023893bb506ead6,
                },
        );
    }
}


