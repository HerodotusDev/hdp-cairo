use hdp_cairo::{Memorizer, utils::chain_id::ChainId};
use starknet::syscalls::call_contract_syscall;
use starknet::SyscallResultTrait;

const ACCOUNT_MEMORIZER: felt252 = 1;

const ACCOUNT_MEMORIZER_GET_NONCE: felt252 = 0;
const ACCOUNT_MEMORIZER_GET_BALANCE: felt252 = 1;
const ACCOUNT_MEMORIZER_GET_STATE_ROOT: felt252 = 2;
const ACCOUNT_MEMORIZER_GET_CODE_HASH: felt252 = 3;

#[derive(Serde, Drop)]
pub struct AccountKey {
    pub chain_id: ChainId,
    pub block_number: felt252,
    pub address: felt252,
}

#[generate_trait]
pub impl AccountMemorizerImpl of AccountMemorizerTrait {
    fn get_nonce(self: @Memorizer, key: AccountKey) -> u256 {
        let value = call_contract_syscall(
            ACCOUNT_MEMORIZER.try_into().unwrap(),
            ACCOUNT_MEMORIZER_GET_NONCE,
            array![
                *self.dict.segment_index,
                *self.dict.offset,
                key.chain_id.into(),
                key.block_number,
                key.address,
            ]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
    fn get_balance(self: @Memorizer, key: AccountKey) -> u256 {
        let value = call_contract_syscall(
            ACCOUNT_MEMORIZER.try_into().unwrap(),
            ACCOUNT_MEMORIZER_GET_BALANCE,
            array![
                *self.dict.segment_index,
                *self.dict.offset,
                key.chain_id.into(),
                key.block_number,
                key.address,
            ]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
    fn get_state_root(self: @Memorizer, key: AccountKey) -> u256 {
        let value = call_contract_syscall(
            ACCOUNT_MEMORIZER.try_into().unwrap(),
            ACCOUNT_MEMORIZER_GET_STATE_ROOT,
            array![
                *self.dict.segment_index,
                *self.dict.offset,
                key.chain_id.into(),
                key.block_number,
                key.address,
            ]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
    fn get_code_hash(self: @Memorizer, key: AccountKey) -> u256 {
        let value = call_contract_syscall(
            ACCOUNT_MEMORIZER.try_into().unwrap(),
            ACCOUNT_MEMORIZER_GET_CODE_HASH,
            array![
                *self.dict.segment_index,
                *self.dict.offset,
                key.chain_id.into(),
                key.block_number,
                key.address,
            ]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
}
