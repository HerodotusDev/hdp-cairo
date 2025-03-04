#[starknet::contract]
mod logs_get_address {
    use hdp_cairo::{HDP, evm::log::{LogImpl, LogKey, LogTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .log_get_address(
                    @LogKey {
                        chain_id: 11155111,
                        block_number: 7692344,
                        transaction_index: 180,
                        log_index: 0,
                    },
                ) == u256 { low: 0xE1A608bcc77C2d392093cE7F05c0DB14, high: 0x7Eaa8557 },
        );
    }
}

#[starknet::contract]
mod logs_get_topic0 {
    use hdp_cairo::{HDP, evm::log::{LogImpl, LogKey, LogTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .log_get_topic0(
                    @LogKey {
                        chain_id: 11155111,
                        block_number: 7692344,
                        transaction_index: 180,
                        log_index: 0,
                    },
                ) == u256 {
                    low: 0xdd0314c0f7b2291e5b200ac8c7c3b925,
                    high: 0x8c5be1e5ebec7d5bd14f71427d1e84f3,
                },
        );
    }
}

#[starknet::contract]
mod logs_get_topic1 {
    use hdp_cairo::{HDP, evm::log::{LogImpl, LogKey, LogTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .log_get_topic1(
                    @LogKey {
                        chain_id: 11155111,
                        block_number: 7692344,
                        transaction_index: 180,
                        log_index: 0,
                    },
                ) == u256 { low: 0xc2eD6f12bF99dAb43C55f40d7D40b730, high: 0xfB41B2F3 },
        );
    }
}

#[starknet::contract]
mod logs_get_topic2 {
    use hdp_cairo::{HDP, evm::log::{LogImpl, LogKey, LogTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .log_get_topic2(
                    @LogKey {
                        chain_id: 11155111,
                        block_number: 7692344,
                        transaction_index: 180,
                        log_index: 0,
                    },
                ) == u256 { low: 0x798deddCAf5EB9264a3b8D1D7c4f09d7, high: 0x421c3ab6 },
        );
    }
}

#[starknet::contract]
mod logs_get_data {
    use alexandria_bytes::{Bytes, BytesTrait};
    use alexandria_encoding::sol_abi::{decode::SolAbiDecodeTrait};
    use hdp_cairo::{HDP, evm::log::{LogImpl, LogKey, LogTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        let key = LogKey {
            chain_id: 11155111, block_number: 7692344, transaction_index: 180, log_index: 0,
        };
        let mut data = hdp.evm.log_get_data(@key);
        let encoded: Bytes = BytesTrait::new(data.len() * 0x20, data);

        let mut offset = 0;
        let decoded: u256 = encoded.decode(ref offset);

        assert!(decoded == u256 { low: 0xde0b6b3a7640000, high: 0x0 });
    }
}
