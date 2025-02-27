#[starknet::contract]
mod module {
    use core::starknet::EthAddress;
    use hdp_cairo::HDP;
    use hdp_cairo::evm::{ETHEREUM_TESTNET_CHAIN_ID, account::{AccountKey, AccountTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(
        ref self: ContractState, hdp: HDP, address: EthAddress, blocks: Array<felt252>,
    ) -> u256 {
        let len: u32 = blocks.len();
        let mut counter: u32 = 0;
        let mut sum: u256 = 0;

        while counter < len {
            sum += hdp
                .evm
                .account_get_balance(
                    @AccountKey {
                        chain_id: ETHEREUM_TESTNET_CHAIN_ID,
                        address: address.into(),
                        block_number: *blocks[counter],
                    },
                );
            counter += 1;
        };

        sum / u256 { low: counter.into(), high: 0 }
    }
}
