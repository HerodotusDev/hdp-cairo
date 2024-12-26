#[starknet::contract]
mod get_nonce {
    use hdp_cairo::evm::account::AccountTrait;
    use hdp_cairo::{HDP, evm::account::{AccountKey, AccountImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, address: felt252) -> u256 {
        hdp
            .evm
            .account_get_nonce(
                AccountKey { chain_id: 11155111, block_number: block_number.into(), address }
            )
    }
}

#[starknet::contract]
mod get_balance {
    use hdp_cairo::evm::account::AccountTrait;
    use hdp_cairo::{HDP, evm::account::{AccountKey, AccountImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, address: felt252) -> u256 {
        hdp
            .evm
            .account_get_balance(
                AccountKey { chain_id: 11155111, block_number: block_number.into(), address }
            )
    }
}

#[starknet::contract]
mod get_state_root {
    use hdp_cairo::evm::account::AccountTrait;
    use hdp_cairo::{HDP, evm::account::{AccountKey, AccountImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, address: felt252) -> u256 {
        hdp
            .evm
            .account_get_state_root(
                AccountKey { chain_id: 11155111, block_number: block_number.into(), address }
            )
    }
}

#[starknet::contract]
mod get_code_hash {
    use hdp_cairo::evm::account::AccountTrait;
    use hdp_cairo::{HDP, evm::account::{AccountKey, AccountImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, address: felt252) -> u256 {
        hdp
            .evm
            .account_get_code_hash(
                AccountKey { chain_id: 11155111, block_number: block_number.into(), address }
            )
    }
}
