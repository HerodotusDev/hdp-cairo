#[starknet::contract]
mod contract {
    use hdp_cairo::{
        HDP, memorizer::account_memorizer::{AccountKey, AccountMemorizerImpl},
        utils::chain_id::ChainIdTrait
    };

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(
        ref self: ContractState,
        hdp: HDP,
        private_block_range_start: u32,
        private_block_range_end: u32,
        address: felt252
    ) -> u256 {
        let mut i: u32 = private_block_range_start;
        let mut sum: u256 = 0;
        loop {
            if i < private_block_range_end {
                sum += hdp
                    .account_memorizer
                    .get_balance(
                        AccountKey {
                            chain_id: ChainIdTrait::from_str('Ethereum_Sepolia').unwrap(),
                            block_number: i.into(),
                            address: address
                        }
                    )
            } else {
                break;
            }
            i += 1;
        };
        sum
    }
}
