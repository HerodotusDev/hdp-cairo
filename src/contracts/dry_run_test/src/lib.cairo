#[starknet::contract]
mod contract {
    use hdp_cairo::{HDP, memorizer::account_memorizer::{AccountKey, AccountMemorizerImpl}};
    use starknet::syscalls::call_contract_syscall;
    use starknet::{ContractAddress, SyscallResult, SyscallResultTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(
        ref self: ContractState,
        hdp: HDP,
        block_range_start: u32,
        block_range_end: u32,
        address: felt252
    ) -> u256 {
        let mut i: u32 = block_range_start;
        let mut sum: u256 = 0;
        loop {
            if i < block_range_end {
                sum += hdp
                    .account_memorizer
                    .get_balance(
                        AccountKey { chain_id: 11155111, block_number: i.into(), address: address }
                    )
            } else {
                break;
            }
            i += 1;
        };
        sum
    }
}
