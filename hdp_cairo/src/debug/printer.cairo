use starknet::syscalls::call_contract_syscall;
use starknet::{SyscallResult, SyscallResultTrait};

const DEBUG_CONTRACT_ADDRESS: felt252 = 99;
const PRINT: felt252 = 0;

pub fn print(value: felt252) {
    print_array(array![value]);
}

pub fn print_array(array: Array<felt252>) {
    call_contract_syscall(
        DEBUG_CONTRACT_ADDRESS.try_into().unwrap(),
        PRINT,
        array.span()
    )
        .unwrap_syscall();
}