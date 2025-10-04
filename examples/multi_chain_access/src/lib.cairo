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
                        chain_id: 10,
                        block_number: 140994910,
                        address: 0x58e6433a6903886e440ddf519ecc573c4046a6b2,
                        storage_slot: 0x0000000000000000000000000000000000000000000000000000000000000014,
                    },
                ) == u256 { low: 0x0000000000000002da6c4233b490d896, high: 0x0 },
        )
    }
}
