#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::evm::{ETHEREUM_TESTNET_CHAIN_ID, storage::{StorageImpl, StorageKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> () {
        let storage_key = StorageKey {
            chain_id: ETHEREUM_TESTNET_CHAIN_ID,
            block_number: 7692344,
            address: 0x75cec1db9dceb703200eaa6595f66885c962b920,
            storage_slot: 2,
        };
        let value = hdp.evm.storage_get_slot(@storage_key);
        println!("Slot value {:x}", value);
    }
}
