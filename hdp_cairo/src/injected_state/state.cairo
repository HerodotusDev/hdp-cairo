use hdp_cairo::InjectedStateMemorizer;
use starknet::SyscallResultTrait;
use starknet::syscalls::call_contract_syscall;

const INJECTED_STATE_CONTRACT_ADDRESS: felt252 = 'injected_state';

const READ_TRIE_ROOT: felt252 = 0;
const READ_KEY: felt252 = 1;
const DOES_KEY_EXIST: felt252 = 2;
const WRITE_KEY: felt252 = 3;

#[generate_trait]
pub impl InjectedStateMemorizerImpl of InjectedStateMemorizerTrait {
    fn read_injected_state_trie_root(
        self: @InjectedStateMemorizer, label: felt252,
    ) -> (felt252, bool) {
        let calldata = array![*self.dict.segment_index, *self.dict.offset, label];
        let ret_data = call_contract_syscall(
            INJECTED_STATE_CONTRACT_ADDRESS.try_into().unwrap(), READ_TRIE_ROOT, calldata.span(),
        )
            .unwrap_syscall();
        let root = *ret_data.at(0);
        let exists = *ret_data.at(1) == 1;

        (root, exists)
    }

    fn read_key(self: @InjectedStateMemorizer, key: felt252) -> (felt252, bool) {
        let calldata = array![*self.dict.segment_index, *self.dict.offset, key];
        let ret_data = call_contract_syscall(
            INJECTED_STATE_CONTRACT_ADDRESS.try_into().unwrap(), READ_KEY, calldata.span(),
        )
            .unwrap_syscall();
        let value = *ret_data.at(0);
        let exists = *ret_data.at(1) == 1;

        (value, exists)
    }

    fn does_key_exist(self: @InjectedStateMemorizer, key: felt252) -> bool {
        let (_value, exists) = self.read_key(key);
        exists
    }

    fn write_key(self: @InjectedStateMemorizer, key: felt252, value: felt252) -> bool {
        let calldata = array![*self.dict.segment_index, *self.dict.offset, key, value];
        let ret_data = call_contract_syscall(
            INJECTED_STATE_CONTRACT_ADDRESS.try_into().unwrap(), WRITE_KEY, calldata.span(),
        )
            .unwrap_syscall();
        *ret_data.at(0) == 1
    }
}
