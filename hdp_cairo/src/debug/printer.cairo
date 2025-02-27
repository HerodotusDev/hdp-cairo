use core::fmt::Display;
use starknet::SyscallResultTrait;
use starknet::syscalls::call_contract_syscall;


const DEBUG_CONTRACT_ADDRESS: felt252 = 'debug';
const PRINT: felt252 = 0;
const PRINT_ARRAY: felt252 = 1;

pub fn print<T, +Display<T>, +Drop<T>>(value: T) {
    let msg: ByteArray = format!("{}", value);
    let mut output_array = array![];
    msg.serialize(ref output_array);
    call_contract_syscall(DEBUG_CONTRACT_ADDRESS.try_into().unwrap(), PRINT, output_array.span())
        .unwrap_syscall();
}

pub fn print_array(array: Array<felt252>) {
    call_contract_syscall(DEBUG_CONTRACT_ADDRESS.try_into().unwrap(), PRINT_ARRAY, array.span())
        .unwrap_syscall();
}
