#[starknet::contract]
mod get_parent {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderKey, HeaderImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_parent(
                    HeaderKey { chain_id: 11155111, block_number: 6000000 }
                ) == u256 {
                    low: 0x5cfce27b38bbb87ab1be0318c5a6e312,
                    high: 0x21e65fc6e962d4c8d0a0fb7a9e3d3f71
                }
        )
    }
}

#[starknet::contract]
mod get_uncle {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderKey, HeaderImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_uncle(
                    HeaderKey { chain_id: 11155111, block_number: 6000000 }
                ) == u256 {
                    low: 0xd312451b948a7413f0a142fd40d49347,
                    high: 0x1dcc4de8dec75d7aab85b567b6ccd41a
                }
        )
    }
}

#[starknet::contract]
mod get_coinbase {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderKey, HeaderImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_coinbase(
                    HeaderKey { chain_id: 11155111, block_number: 6000000 }
                ) == u256 { low: 0x88762ad8061c04d08c37902abc8acb87, high: 0x9b7e3350 }
        )
    }
}

#[starknet::contract]
mod get_state_root {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderKey, HeaderImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_state_root(
                    HeaderKey { chain_id: 11155111, block_number: 6000000 }
                ) == u256 {
                    low: 0x817271e87d530571fd93beefe826af78,
                    high: 0x2378fe6355340aec33ac0a401efcd9b4
                }
        )
    }
}

#[starknet::contract]
mod get_transaction_root {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderKey, HeaderImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_transaction_root(
                    HeaderKey { chain_id: 11155111, block_number: 6000000 }
                ) == u256 {
                    low: 0xe24369f85f9dcf8a53c2b7f93cdd4309,
                    high: 0xfdfa9ffadb4cf0f880207c17a0aaf854
                }
        )
    }
}

#[starknet::contract]
mod get_receipt_root {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderKey, HeaderImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_receipt_root(
                    HeaderKey { chain_id: 11155111, block_number: 6000000 }
                ) == u256 {
                    low: 0x38f73a78b0e0a6f606e6c07fc0954733,
                    high: 0xa1221588b2b63fdc80106f1e11ccbe96
                }
        )
    }
}

#[starknet::contract]
mod get_difficulty {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderKey, HeaderImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_difficulty(
                    HeaderKey { chain_id: 11155111, block_number: 6000000 }
                ) == u256 { low: 0x0, high: 0x0 }
        )
    }
}

#[starknet::contract]
mod get_number {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderKey, HeaderImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_number(
                    HeaderKey { chain_id: 11155111, block_number: 6000000 }
                ) == u256 { low: 0x5b8d80, high: 0x0 }
        )
    }
}

#[starknet::contract]
mod get_gas_limit {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderKey, HeaderImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_gas_limit(
                    HeaderKey { chain_id: 11155111, block_number: 6000000 }
                ) == u256 { low: 0x1c9c380, high: 0x0 }
        )
    }
}

#[starknet::contract]
mod get_gas_used {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderKey, HeaderImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_gas_used(
                    HeaderKey { chain_id: 11155111, block_number: 6000000 }
                ) == u256 { low: 0x106170a, high: 0x0 }
        )
    }
}

#[starknet::contract]
mod get_mix_hash {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderKey, HeaderImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_mix_hash(
                    HeaderKey { chain_id: 11155111, block_number: 6000000 }
                ) == u256 {
                    low: 0x989953cfee51aaee0e838f7c56a8c959,
                    high: 0x525eb521f3b6c59b369135daae3b715a
                }
        )
    }
}

#[starknet::contract]
mod get_nonce {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderKey, HeaderImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_nonce(
                    HeaderKey { chain_id: 11155111, block_number: 6000000 }
                ) == u256 { low: 0x0, high: 0x0 }
        )
    }
}

#[starknet::contract]
mod get_base_fee_per_gas {
    use hdp_cairo::evm::header::HeaderTrait;
    use hdp_cairo::{HDP, evm::header::{HeaderKey, HeaderImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .header_get_base_fee_per_gas(
                    HeaderKey { chain_id: 11155111, block_number: 6000000 }
                ) == u256 { low: 0x79820dc63, high: 0x0 }
        )
    }
}
