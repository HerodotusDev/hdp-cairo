use starknet::SyscallResultTrait;
use starknet::syscalls::call_contract_syscall;

use super::{InjectedState};

const INJECTED_STATE: felt252 = 1;

// Selectors
const READ_KEY: felt252 = 0;
const UPSERT_KEY: felt252 = 1;
const DOES_KEY_EXIST: felt252 = 2;


#[generate_trait]
impl InjectedStateImpl of InjectedStateTrait {
    fn read_key(self: @InjectedState, key: felt252) -> (felt252, bool) {
        let calldata = array![*self.dict.segment_index, *self.dict.offset, key];
        let ret_data = call_contract_syscall(
            INJECTED_STATE.try_into().unwrap(), READ_KEY, calldata.span(),
        )
            .unwrap_syscall();

        let value = *ret_data.at(0);
        let exists = *ret_data.at(1) == 1;
        (value, exists)
    }

    fn upsert_key(self: @InjectedState, key: felt252, value: felt252) -> bool {
        let calldata = array![*self.dict.segment_index, *self.dict.offset, key, value];
        let ret_data = call_contract_syscall(
            INJECTED_STATE.try_into().unwrap(), UPSERT_KEY, calldata.span(),
        )
            .unwrap_syscall();
        *ret_data.at(0) == 1
    }

    fn does_key_exist(self: @InjectedState, key: felt252) -> bool {
        let calldata = array![*self.dict.segment_index, *self.dict.offset, key];
        let ret_data = call_contract_syscall(
            INJECTED_STATE.try_into().unwrap(), DOES_KEY_EXIST, calldata.span(),
        )
            .unwrap_syscall();
        *ret_data.at(0) == 1
    }
}
