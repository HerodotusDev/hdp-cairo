#[starknet::contract]
mod contract {
    use hdp_cairo::{HDP, memorizer::account_memorizer::{AccountKey, AccountMemorizerImpl}};
    use starknet::syscalls::call_contract_syscall;
    use starknet::{ContractAddress, SyscallResult, SyscallResultTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> u256 {
        hdp
            .account_memorizer
            .get_balance(
                AccountKey {
                    chain_id: 1,
                    block_number: 6203471,
                    address: 0x13CB6AE34A13a0977F4d7101eBc24B87Bb23F0d5
                }
            )
    }
}
