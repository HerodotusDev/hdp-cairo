// Simple example: access and return a specified storage slot from Starknet at a given block.
#[starknet::contract]
mod starknet_storage {
    use hdp_cairo::HDP;
    use hdp_cairo::starknet::storage::{StorageImpl, StorageKey, StorageTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(
        ref self: ContractState,
        hdp: HDP,
        chain_id: felt252,
        block_number: u64,
        address: felt252,
        storage_slot: felt252,
    ) -> felt252 {
        hdp.starknet.storage_get_slot(@StorageKey {
            chain_id,
            block_number: block_number.into(),
            address,
            storage_slot,
        })
    }
}
