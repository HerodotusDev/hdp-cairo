#[starknet::contract]
mod module {
    use hdp_cairo::evm::storage::StorageTrait;
   // use hdp_cairo::{HDP, evm::storage::{StorageImpl, StorageKey}};
   // use hdp_cairo::{HDP, starknet::storage::{StorageImpl, StorageKey}};
    use hdp_cairo::{HDP, evm::header::{HeaderImpl, HeaderKey}};
    use hdp_cairo::{starknet::header::{HeaderImpl as StarknetHeaderImpl, HeaderKey as StarknetHeaderKey}};


    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP)  -> u256 {
        // assert!(
        //     hdp
        //         .evm
        //         .storage_get_slot(
        //             @StorageKey {
        //                 chain_id: 10,
        //                 block_number: 140994910,
        //                 address: 0x58e6433a6903886e440ddf519ecc573c4046a6b2,
        //                 storage_slot: 0x0000000000000000000000000000000000000000000000000000000000000014,
        //             },
        //         ) == u256 { low: 0x0000000000000002da6c4233b490d896, high: 0x0 },
        // )

        // hdp
        //     .starknet
        //     .storage_get_slot(
        //         @StorageKey {
        //             chain_id: 393402133025997798000961,
        //             block_number: 517902,
        //             address: 0x6b8838af5d2a023b24ec8a69720b152d72ae2e4528139c32e05d8a3b9d7d4e7,
        //             storage_slot: 0x308cfbb7d2d38db3a215f9728501ac69445a6afbee328cdeae4e23db54b850a,
        //         },
        //     )


        // hdp
        //     .evm
        //     .storage_get_slot(
        //         @StorageKey {
        //             chain_id: 11155111,
        //             block_number: 8838214,
        //             address: 0x9ae18109692b43e95ae6be5350a5acc5211fe9a1,
        //             storage_slot: 0x0000000000000000000000000000000000000000000000000000000000000008,
        //         },
        //     )


        // hdp
        //     .evm
        //     .storage_get_slot(
        //         @StorageKey {
        //             chain_id: 11155420,
        //             block_number: 32860659,
        //             address: 0x5a4aaa060ab41b5d27c1f3cb8cbccb39d2cd8ea6,
        //             storage_slot: 0x000000000000000000000000000000000000000000000000000000000000001b,
        //         },
        //     )

          hdp
                .evm
                .header_get_parent(
                    @HeaderKey { chain_id: 11155111, block_number: 8838214 },
                );


         hdp
            .starknet
            .header_get_event_count(
                @StarknetHeaderKey { chain_id: 393402133025997798000961, block_number: 8734658 },
            );


                  hdp
                .evm
                .header_get_parent(
                    @HeaderKey { chain_id: 11155420, block_number: 32860659 },
                )
        
    }
}
