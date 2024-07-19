use hdp_cairo::Memorizer;
use starknet::syscalls::call_contract_syscall;
use starknet::{SyscallResult, SyscallResultTrait};

const HEADER_MEMORIZER: felt252 = 0;

const HEADER_MEMORIZER_GET_PARENT: felt252 = 0;
const HEADER_MEMORIZER_GET_UNCLE: felt252 = 1;
const HEADER_MEMORIZER_GET_COINBASE: felt252 = 2;
const HEADER_MEMORIZER_GET_STATE_ROOT: felt252 = 3;
const HEADER_MEMORIZER_GET_TRANSACTION_ROOT: felt252 = 4;
const HEADER_MEMORIZER_GET_RECEIPT_ROOT: felt252 = 5;
const HEADER_MEMORIZER_GET_BLOOM: felt252 = 6;
const HEADER_MEMORIZER_GET_DIFFICULTY: felt252 = 7;
const HEADER_MEMORIZER_GET_NUMBER: felt252 = 8;
const HEADER_MEMORIZER_GET_GAS_LIMIT: felt252 = 9;
const HEADER_MEMORIZER_GET_GAS_USED: felt252 = 10;
const HEADER_MEMORIZER_GET_TIMESTAMP: felt252 = 11;
const HEADER_MEMORIZER_GET_EXTRA_DATA: felt252 = 12;
const HEADER_MEMORIZER_GET_MIX_HASH: felt252 = 13;
const HEADER_MEMORIZER_GET_NONCE: felt252 = 14;
const HEADER_MEMORIZER_GET_BASE_FEE_PER_GAS: felt252 = 15;
const HEADER_MEMORIZER_GET_WITHDRAWALS_ROOT: felt252 = 16;
const HEADER_MEMORIZER_GET_BLOB_GAS_USED: felt252 = 17;
const HEADER_MEMORIZER_GET_EXCESS_BLOB_GAS: felt252 = 18;
const HEADER_MEMORIZER_GET_PARENT_BEACON_BLOCK_ROOT: felt252 = 19;

#[derive(Serde, Drop)]
pub struct HeaderKey {
    pub chain_id: felt252,
    pub block_number: felt252,
}

#[generate_trait]
pub impl HeaderMemorizerImpl of HeaderMemorizerTrait {
    fn get_parent(self: @Memorizer, key: HeaderKey) -> u256 {
        let value = call_contract_syscall(
            HEADER_MEMORIZER.try_into().unwrap(),
            HEADER_MEMORIZER_GET_PARENT,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
    fn get_uncle(self: @Memorizer, key: HeaderKey) -> u256 {
        let value = call_contract_syscall(
            HEADER_MEMORIZER.try_into().unwrap(),
            HEADER_MEMORIZER_GET_UNCLE,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
    fn get_coinbase(self: @Memorizer, key: HeaderKey) -> u256 {
        let value = call_contract_syscall(
            HEADER_MEMORIZER.try_into().unwrap(),
            HEADER_MEMORIZER_GET_COINBASE,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
    fn get_state_root(self: @Memorizer, key: HeaderKey) -> u256 {
        let value = call_contract_syscall(
            HEADER_MEMORIZER.try_into().unwrap(),
            HEADER_MEMORIZER_GET_STATE_ROOT,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
    fn get_transaction_root(self: @Memorizer, key: HeaderKey) -> u256 {
        let value = call_contract_syscall(
            HEADER_MEMORIZER.try_into().unwrap(),
            HEADER_MEMORIZER_GET_TRANSACTION_ROOT,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
    fn get_receipt_root(self: @Memorizer, key: HeaderKey) -> u256 {
        let value = call_contract_syscall(
            HEADER_MEMORIZER.try_into().unwrap(),
            HEADER_MEMORIZER_GET_RECEIPT_ROOT,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
    fn get_difficulty(self: @Memorizer, key: HeaderKey) -> u256 {
        let value = call_contract_syscall(
            HEADER_MEMORIZER.try_into().unwrap(),
            HEADER_MEMORIZER_GET_DIFFICULTY,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
    fn get_number(self: @Memorizer, key: HeaderKey) -> u256 {
        let value = call_contract_syscall(
            HEADER_MEMORIZER.try_into().unwrap(),
            HEADER_MEMORIZER_GET_NUMBER,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
    fn get_gas_limit(self: @Memorizer, key: HeaderKey) -> u256 {
        let value = call_contract_syscall(
            HEADER_MEMORIZER.try_into().unwrap(),
            HEADER_MEMORIZER_GET_GAS_LIMIT,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
    fn get_gas_used(self: @Memorizer, key: HeaderKey) -> u256 {
        let value = call_contract_syscall(
            HEADER_MEMORIZER.try_into().unwrap(),
            HEADER_MEMORIZER_GET_GAS_USED,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
    fn get_mix_hash(self: @Memorizer, key: HeaderKey) -> u256 {
        let value = call_contract_syscall(
            HEADER_MEMORIZER.try_into().unwrap(),
            HEADER_MEMORIZER_GET_MIX_HASH,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
    fn get_nonce(self: @Memorizer, key: HeaderKey) -> u256 {
        let value = call_contract_syscall(
            HEADER_MEMORIZER.try_into().unwrap(),
            HEADER_MEMORIZER_GET_NONCE,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
    fn get_base_fee_per_gas(self: @Memorizer, key: HeaderKey) -> u256 {
        let value = call_contract_syscall(
            HEADER_MEMORIZER.try_into().unwrap(),
            HEADER_MEMORIZER_GET_BASE_FEE_PER_GAS,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
}
