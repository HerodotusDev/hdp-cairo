#[starknet::contract]
mod evm_storage_get_slot {
    use hdp_cairo::evm::storage::StorageTrait;
    use hdp_cairo::{HDP, evm::storage::{StorageImpl, StorageKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .storage_get_slot(
                    @StorageKey {
                        chain_id: 11155111,
                        block_number: 7692344,
                        address: 0x75cec1db9dceb703200eaa6595f66885c962b920,
                        storage_slot: 0x1,
                    },
                ) == u256 { low: 0x12309ce54000, high: 0x0 },
        )
    }
}
