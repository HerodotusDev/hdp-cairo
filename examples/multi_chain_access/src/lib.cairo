#[starknet::contract]
mod module {
    use hdp_cairo::{HDP, evm::header::{HeaderImpl, HeaderKey}};
    use hdp_cairo::{starknet::header::{HeaderImpl as StarknetHeaderImpl, HeaderKey as StarknetHeaderKey}};


    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP)  -> u256 {
        hdp
            .evm
            .header_get_parent(
                @HeaderKey { chain_id: 11155111, block_number: 8838214 },
            );


        hdp
            .starknet
            .header_get_block_number(
                @StarknetHeaderKey { chain_id: 393402133025997798000961, block_number: 517902 },
            );


        hdp
            .evm
            .header_get_parent(
                @HeaderKey { chain_id: 11155420, block_number: 32860659 },
            )
        
    }
}
