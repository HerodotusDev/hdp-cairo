#[starknet::contract]
mod module {
    use core::starknet::EthAddress;
    use hdp_cairo::{HDP, evm::log::{LogImpl, LogKey, LogTrait}};

    #[storage]
    struct Storage {}

    struct EVMApprovalEvent {
        owner: EthAddress,
        spender: EthAddress,
        value: u256,
    }

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        let key = LogKey {
            chain_id: 11155111, block_number: 7692344, transaction_index: 180, log_index: 0,
        };
        let mut data = hdp.evm.log_get_data(@key);

        let event = EVMApprovalEvent {
            owner: hdp.evm.log_get_topic1(@key).into(),
            spender: hdp.evm.log_get_topic2(@key).into(),
            value: Serde::deserialize(ref data).unwrap(),
        };

        assert!(event.owner == 0xfB41B2F3c2eD6f12bF99dAb43C55f40d7D40b730.try_into().unwrap());
        assert!(event.spender == 0x421c3ab6798deddCAf5EB9264a3b8D1D7c4f09d7.try_into().unwrap());
        assert!(event.value == u256 { low: 0xde0b6b3a7640000, high: 0x0 });
    }
}
