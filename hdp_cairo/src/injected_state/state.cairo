use hdp_cairo::InjectedStateMemorizer;
use starknet::SyscallResultTrait;
use starknet::syscalls::call_contract_syscall;

const INJECTED_STATE_CONTRACT_ADDRESS: felt252 = 'injected_state';

const LABEL: felt252 = 0;
const READ: felt252 = 1;
const WRITE: felt252 = 2;

#[generate_trait]
pub impl InjectedStateMemorizerImpl of InjectedStateMemorizerTrait {
    fn read_injected_state_trie_root(
        self: @InjectedStateMemorizer, label: felt252,
    ) -> Option<felt252> {
        let calldata = array![*self.dict.segment_index, *self.dict.offset, label];
        let ret_data = call_contract_syscall(
            INJECTED_STATE_CONTRACT_ADDRESS.try_into().unwrap(), LABEL, calldata.span(),
        )
            .unwrap_syscall();
        let value = *ret_data.at(0);
        let exists = *ret_data.at(1) == 1;

        if exists == true {
            return Option::Some(value);
        } else {
            return Option::None;
        }
    }

    fn read_key(self: @InjectedStateMemorizer, label: felt252, key: felt252) -> Option<felt252> {
        let calldata = array![*self.dict.segment_index, *self.dict.offset, label, key];
        let ret_data = call_contract_syscall(
            INJECTED_STATE_CONTRACT_ADDRESS.try_into().unwrap(), READ, calldata.span(),
        )
            .unwrap_syscall();
        let value = *ret_data.at(0);
        let exists = *ret_data.at(1) == 1;

        if exists == true {
            return Option::Some(value);
        } else {
            return Option::None;
        }
    }

    // @notice Returns the updated trie root
    fn write_key(
        self: @InjectedStateMemorizer, label: felt252, key: felt252, value: felt252,
    ) -> felt252 {
        let calldata = array![*self.dict.segment_index, *self.dict.offset, label, key, value];
        let ret_data = call_contract_syscall(
            INJECTED_STATE_CONTRACT_ADDRESS.try_into().unwrap(), WRITE, calldata.span(),
        )
            .unwrap_syscall();
        *ret_data.at(0)
    }
}
