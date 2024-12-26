#[starknet::contract]
mod get_nonce {
    use hdp_cairo::evm::block_tx::BlockTxTrait;
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, index: u32) -> u256 {
        hdp
            .evm
            .block_tx_get_nonce(
                BlockTxKey {
                    chain_id: 11155111, block_number: block_number.into(), index: index.into()
                }
            )
    }
}

#[starknet::contract]
mod get_gas_price {
    use hdp_cairo::evm::block_tx::BlockTxTrait;
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, index: u32) -> u256 {
        hdp
            .evm
            .block_tx_get_gas_price(
                BlockTxKey {
                    chain_id: 11155111, block_number: block_number.into(), index: index.into()
                }
            )
    }
}

#[starknet::contract]
mod get_gas_limit {
    use hdp_cairo::evm::block_tx::BlockTxTrait;
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, index: u32) -> u256 {
        hdp
            .evm
            .block_tx_get_gas_limit(
                BlockTxKey {
                    chain_id: 11155111, block_number: block_number.into(), index: index.into()
                }
            )
    }
}

#[starknet::contract]
mod get_receiver {
    use hdp_cairo::evm::block_tx::BlockTxTrait;
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, index: u32) -> u256 {
        hdp
            .evm
            .block_tx_get_receiver(
                BlockTxKey {
                    chain_id: 11155111, block_number: block_number.into(), index: index.into()
                }
            )
    }
}

#[starknet::contract]
mod get_value {
    use hdp_cairo::evm::block_tx::BlockTxTrait;
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, index: u32) -> u256 {
        hdp
            .evm
            .block_tx_get_value(
                BlockTxKey {
                    chain_id: 11155111, block_number: block_number.into(), index: index.into()
                }
            )
    }
}

#[starknet::contract]
mod get_v {
    use hdp_cairo::evm::block_tx::BlockTxTrait;
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, index: u32) -> u256 {
        hdp
            .evm
            .block_tx_get_v(
                BlockTxKey {
                    chain_id: 11155111, block_number: block_number.into(), index: index.into()
                }
            )
    }
}

#[starknet::contract]
mod get_r {
    use hdp_cairo::evm::block_tx::BlockTxTrait;
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, index: u32) -> u256 {
        hdp
            .evm
            .block_tx_get_r(
                BlockTxKey {
                    chain_id: 11155111, block_number: block_number.into(), index: index.into()
                }
            )
    }
}

#[starknet::contract]
mod get_s {
    use hdp_cairo::evm::block_tx::BlockTxTrait;
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, index: u32) -> u256 {
        hdp
            .evm
            .block_tx_get_s(
                BlockTxKey {
                    chain_id: 11155111, block_number: block_number.into(), index: index.into()
                }
            )
    }
}

#[starknet::contract]
mod get_chain_id {
    use hdp_cairo::evm::block_tx::BlockTxTrait;
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, index: u32) -> u256 {
        hdp
            .evm
            .block_tx_get_chain_id(
                BlockTxKey {
                    chain_id: 11155111, block_number: block_number.into(), index: index.into()
                }
            )
    }
}

#[starknet::contract]
mod get_max_fee_per_gas {
    use hdp_cairo::evm::block_tx::BlockTxTrait;
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, index: u32) -> u256 {
        hdp
            .evm
            .block_tx_get_max_fee_per_gas(
                BlockTxKey {
                    chain_id: 11155111, block_number: block_number.into(), index: index.into()
                }
            )
    }
}

#[starknet::contract]
mod get_max_priority_fee_per_gas {
    use hdp_cairo::evm::block_tx::BlockTxTrait;
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, index: u32) -> u256 {
        hdp
            .evm
            .block_tx_get_max_priority_fee_per_gas(
                BlockTxKey {
                    chain_id: 11155111, block_number: block_number.into(), index: index.into()
                }
            )
    }
}

#[starknet::contract]
mod get_max_fee_per_blob_gas {
    use hdp_cairo::evm::block_tx::BlockTxTrait;
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, index: u32) -> u256 {
        hdp
            .evm
            .block_tx_get_max_fee_per_blob_gas(
                BlockTxKey {
                    chain_id: 11155111, block_number: block_number.into(), index: index.into()
                }
            )
    }
}

#[starknet::contract]
mod get_tx_type {
    use hdp_cairo::evm::block_tx::BlockTxTrait;
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, index: u32) -> u256 {
        hdp
            .evm
            .block_tx_get_tx_type(
                BlockTxKey {
                    chain_id: 11155111, block_number: block_number.into(), index: index.into()
                }
            )
    }
}

#[starknet::contract]
mod get_sender {
    use hdp_cairo::evm::block_tx::BlockTxTrait;
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, index: u32) -> u256 {
        hdp
            .evm
            .block_tx_get_sender(
                BlockTxKey {
                    chain_id: 11155111, block_number: block_number.into(), index: index.into()
                }
            )
    }
}
