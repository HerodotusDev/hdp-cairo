use hdp_cairo::InjectedStateMemorizer;
use starknet::SyscallResultTrait;
use starknet::syscalls::call_contract_syscall;

const INJECTED_STATE_CONTRACT_ADDRESS: felt252 = 'injected_state';

const READ_KEY: felt252 = 0;
const UPSERT_KEY: felt252 = 1;
const DOES_KEY_EXIST: felt252 = 2;

#[generate_trait]
pub impl InjectedStateMemorizerImpl of InjectedStateMemorizerTrait {
    fn read_key(self: @InjectedStateMemorizer, key: felt252) -> (felt252, bool) {
        let msg: ByteArray = format!("{}", key);
        let mut output_array = array![];
        msg.serialize(ref output_array);
        let ret_data = call_contract_syscall(
            INJECTED_STATE_CONTRACT_ADDRESS.try_into().unwrap(), READ_KEY, output_array.span(),
        )
            .unwrap_syscall();

        let value = *ret_data.at(0);
        let exists = *ret_data.at(1) == 1;
        (value, exists)
    }

    fn upsert_key(self: @InjectedStateMemorizer, key: felt252, value: felt252) -> bool {
        let calldata = array![*self.dict.segment_index, *self.dict.offset, key, value];
        let ret_data = call_contract_syscall(
            INJECTED_STATE_CONTRACT_ADDRESS.try_into().unwrap(), UPSERT_KEY, calldata.span(),
        )
            .unwrap_syscall();
        *ret_data.at(0) == 1
    }

    fn does_key_exist(self: @InjectedStateMemorizer, key: felt252) -> bool {
        let calldata = array![*self.dict.segment_index, *self.dict.offset, key];
        let ret_data = call_contract_syscall(
            INJECTED_STATE_CONTRACT_ADDRESS.try_into().unwrap(), DOES_KEY_EXIST, calldata.span(),
        )
            .unwrap_syscall();
        *ret_data.at(0) == 1
    }
}
