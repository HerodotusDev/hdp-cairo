#[starknet::contract]
mod contract {
    use hdp_cairo::{HDP, memorizer::account_memorizer::{AccountKey, AccountMemorizerImpl}};
    use starknet::syscalls::call_contract_syscall;
    use starknet::{ContractAddress, SyscallResult, SyscallResultTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> u256 {
        let mut i: u32 = 0;
        let mut sum: u256 = 0;
        loop {
            if i < 10 {
                sum += hdp
                    .account_memorizer
                    .get_balance(
                        AccountKey {
                            chain_id: 1,
                            block_number: (6203471 + i).into(),
                            address: 0x13CB6AE34A13a0977F4d7101eBc24B87Bb23F0d5
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
