use hdp_cairo::EvmMemorizer;
use starknet::syscalls::call_contract_syscall;
use starknet::{SyscallResult, SyscallResultTrait};

const ACCOUNT: felt252 = 1;

const ACCOUNT_GET_NONCE: felt252 = 0;
const ACCOUNT_GET_BALANCE: felt252 = 1;
const ACCOUNT_GET_STATE_ROOT: felt252 = 2;
const ACCOUNT_GET_CODE_HASH: felt252 = 3;

#[derive(Serde, Drop)]
pub struct AccountKey {
    pub chain_id: felt252,
    pub block_number: felt252,
    pub address: felt252,
}

#[generate_trait]
pub impl AccountImpl of AccountTrait {
    fn account_get_nonce(self: @EvmMemorizer, key: AccountKey) -> u256 {
        self.call_memorizer(ACCOUNT_GET_NONCE, key)
    }
    fn account_get_balance(self: @EvmMemorizer, key: AccountKey) -> u256 {
        self.call_memorizer(ACCOUNT_GET_BALANCE, key)
    }
    fn account_get_state_root(self: @EvmMemorizer, key: AccountKey) -> u256 {
        self.call_memorizer(ACCOUNT_GET_STATE_ROOT, key)
    }
    fn account_get_code_hash(self: @EvmMemorizer, key: AccountKey) -> u256 {
        self.call_memorizer(ACCOUNT_GET_CODE_HASH, key)
    }

    fn call_memorizer(self: @EvmMemorizer, selector: felt252, key: AccountKey) -> u256 {
        let value = call_contract_syscall(
            ACCOUNT.try_into().unwrap(),
            selector,
            array![
                *self.dict.segment_index,
                *self.dict.offset,
                key.chain_id,
                key.block_number,
                key.address,
            ]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
}
