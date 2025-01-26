#[starknet::contract]
mod starknet_get_storage {
    use hdp_cairo::starknet::storage::StorageTrait;
    use hdp_cairo::{HDP, starknet::storage::{StorageKey, StorageImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> felt252 {
        hdp
            .starknet
            .storage_get_slot(
                StorageKey {
                    chain_id: 393402133025997798000961,
                    block_number: 202304,
                    address: 0x6b8838af5d2a023b24ec8a69720b152d72ae2e4528139c32e05d8a3b9d7d4e7,
                    storage_slot: 0x308cfbb7d2d38db3a215f9728501ac69445a6afbee328cdeae4e23db54b850a,
                },
            )
    }
}
