#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::evm::{ETHEREUM_TESTNET_CHAIN_ID, account::{AccountImpl, AccountKey}};
    use hdp_cairo::starknet::{STARKNET_TESTNET_CHAIN_ID, storage::{StorageImpl, StorageKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> u128 {
        0
    }
}
