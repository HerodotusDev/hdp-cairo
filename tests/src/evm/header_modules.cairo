#[starknet::contract]
mod evm_header_get_parent {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderImpl, HeaderKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_parent(
                    HeaderKey { chain_id: 11155111, block_number: 7692344 },
                ) == u256 {
                    low: 0x2bf29adc0426c14ce89ecf3040c01be1,
                    high: 0xf0c0ec0462d1f58b9ac41a9bd43b2b90,
                },
        )
    }
}

#[starknet::contract]
mod evm_header_get_uncle {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderImpl, HeaderKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_uncle(
                    HeaderKey { chain_id: 11155111, block_number: 7692344 },
                ) == u256 {
                    low: 0xd312451b948a7413f0a142fd40d49347,
                    high: 0x1dcc4de8dec75d7aab85b567b6ccd41a,
                },
        )
    }
}

#[starknet::contract]
mod evm_header_get_coinbase {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderImpl, HeaderKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_coinbase(
                    HeaderKey { chain_id: 11155111, block_number: 7692344 },
                ) == u256 {
                    low: 0x71bb64514fc8abbce970307fb9d477e9,
                    high: 0x00000000000000000000000025941dc7,
                },
        )
    }
}

#[starknet::contract]
mod evm_header_get_state_root {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderImpl, HeaderKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_state_root(
                    HeaderKey { chain_id: 11155111, block_number: 7692344 },
                ) == u256 {
                    low: 0x7ddedfe1843a357052c4ab69fb9bd0dd,
                    high: 0xb74b68ae54aaba0e956e18907d52a9f5,
                },
        )
    }
}

#[starknet::contract]
mod evm_header_get_transaction_root {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderImpl, HeaderKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_transaction_root(
                    HeaderKey { chain_id: 11155111, block_number: 7692344 },
                ) == u256 {
                    low: 0x56841dfa609fb3f26ebdbd96e9e979f7,
                    high: 0xec010110bf110e58206dfd3839e0db14,
                },
        )
    }
}

#[starknet::contract]
mod evm_header_get_receipt_root {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderImpl, HeaderKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_receipt_root(
                    HeaderKey { chain_id: 11155111, block_number: 7692344 },
                ) == u256 {
                    low: 0xde42a46e5a513bae11e3df326ca6c471,
                    high: 0xeb44ce8322b3b2757048c0f03f6044f2,
                },
        )
    }
}

#[starknet::contract]
mod evm_header_get_difficulty {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderImpl, HeaderKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_difficulty(
                    HeaderKey { chain_id: 11155111, block_number: 7692344 },
                ) == u256 { low: 0x0, high: 0x0 },
        )
    }
}

#[starknet::contract]
mod evm_header_get_number {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderImpl, HeaderKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_number(
                    HeaderKey { chain_id: 11155111, block_number: 7692344 },
                ) == u256 { low: 0x756038, high: 0x0 },
        )
    }
}

#[starknet::contract]
mod evm_header_get_gas_limit {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderImpl, HeaderKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_gas_limit(
                    HeaderKey { chain_id: 11155111, block_number: 7692344 },
                ) == u256 { low: 0x2255100, high: 0x0 },
        )
    }
}

#[starknet::contract]
mod evm_header_get_gas_used {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderImpl, HeaderKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_gas_used(
                    HeaderKey { chain_id: 11155111, block_number: 7692344 },
                ) == u256 { low: 0x10c275c, high: 0x0 },
        )
    }
}

#[starknet::contract]
mod evm_header_get_mix_hash {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderImpl, HeaderKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_mix_hash(
                    HeaderKey { chain_id: 11155111, block_number: 7692344 },
                ) == u256 {
                    low: 0x429d94aa0b30cf2f5d61d3ba9d235b22,
                    high: 0x8067b447d61fe12f63be05db51899030,
                },
        )
    }
}

#[starknet::contract]
mod evm_header_get_nonce {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderImpl, HeaderKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_nonce(
                    HeaderKey { chain_id: 11155111, block_number: 7692344 },
                ) == u256 { low: 0x0, high: 0x0 },
        )
    }
}

#[starknet::contract]
mod evm_header_get_base_fee_per_gas {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderImpl, HeaderKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_base_fee_per_gas(
                    HeaderKey { chain_id: 11155111, block_number: 7692344 },
                ) == u256 { low: 0x451287161, high: 0x0 },
        )
    }
}
