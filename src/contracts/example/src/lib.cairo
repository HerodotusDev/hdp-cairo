#[starknet::contract]
mod contract {
    pub mod hdp_context;
    use hdp_context::{HDP, header_memorizer::{HeaderKey, HeaderMemorizerImpl}};
    use starknet::syscalls::call_contract_syscall;
    use starknet::{ContractAddress, SyscallResult, SyscallResultTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn main(ref self: ContractState, hdp: HDP) -> u256 {
        hdp.header_memorizer.get_parent(HeaderKey { chain_id: 1, block_number: 5858992, })
    }
}
