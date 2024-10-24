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
        ref self: ContractState, hdp: HDP, mut block_number_list: Array<u32>, address: felt252
    ) -> u256 {
        let mut sum: u256 = 0;
        loop {
            match block_number_list.pop_front() {
                Option::Some(block_number) => {
                    sum += hdp
                        .account_memorizer
                        .get_balance(
                            AccountKey {
                                chain_id: ChainIdTrait::from_str('Ethereum_Sepolia').unwrap(),
                                block_number: block_number.into(),
                                address: address
                            }
                        )
                },
                Option::None => { break; },
            }
        };
        sum
    }
}
