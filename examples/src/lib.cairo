#[starknet::contract]
mod example {
    use hdp_cairo::starknet::storage::StorageTrait;
    use hdp_cairo::{HDP, starknet::storage::{StorageKey, StorageImpl}};
    use core::pedersen::PedersenTrait;
    use core::hash::{HashStateTrait, HashStateExTrait};

    #[derive(Serde, Copy, Drop)]
    struct OrderData {
        transfer_keccak_hash: u256,
    }

    #[storage]
    struct Storage {}

    const TRANSFERS_MAPPING_VARIABLE_NAME_HASH: felt252 =
        0x23ca886028209bdec13b868526ad5645fa06297134296c83a408136a21c987a; // SN_KECCAK of "transfers" string whis is the name of the mapping


    #[external(v0)]
    pub fn main(
        ref self: ContractState,
        hdp: HDP,
        destination_chain_id: felt252,
        payment_registry_address: felt252,
        block_number: u32,
        orders: Array<OrderData>,
    ) -> bool {
        let mut is_verified_correctly: bool = true;
        for order in orders {
            // Calculate storage slot address where key of the mapping is the transfer hash and the
            // value of the mapping is the boolean
            let mut slot = PedersenTrait::new(TRANSFERS_MAPPING_VARIABLE_NAME_HASH)
                .update_with(order.transfer_keccak_hash)
                .finalize();

            let storage_slot_value = hdp
                .starknet
                .storage_get_slot(
                    StorageKey {
                        chain_id: destination_chain_id,
                        block_number: block_number.into(),
                        address: payment_registry_address,
                        storage_slot: slot,
                    },
                );

            if (storage_slot_value != 1) {
                is_verified_correctly = false;
            }
        };
        is_verified_correctly
    }
}
