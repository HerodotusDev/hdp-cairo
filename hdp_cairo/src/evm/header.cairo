use hdp_cairo::EvmMemorizer;
use starknet::syscalls::call_contract_syscall;
use starknet::{SyscallResultTrait};

const HEADER: felt252 = 0;

const HEADER_GET_PARENT: felt252 = 0;
const HEADER_GET_UNCLE: felt252 = 1;
const HEADER_GET_COINBASE: felt252 = 2;
const HEADER_GET_STATE_ROOT: felt252 = 3;
const HEADER_GET_TRANSACTION_ROOT: felt252 = 4;
const HEADER_GET_RECEIPT_ROOT: felt252 = 5;
const HEADER_GET_BLOOM: felt252 = 6;
const HEADER_GET_DIFFICULTY: felt252 = 7;
const HEADER_GET_NUMBER: felt252 = 8;
const HEADER_GET_GAS_LIMIT: felt252 = 9;
const HEADER_GET_GAS_USED: felt252 = 10;
const HEADER_GET_TIMESTAMP: felt252 = 11;
const HEADER_GET_EXTRA_DATA: felt252 = 12;
const HEADER_GET_MIX_HASH: felt252 = 13;
const HEADER_GET_NONCE: felt252 = 14;
const HEADER_GET_BASE_FEE_PER_GAS: felt252 = 15;
const HEADER_GET_WITHDRAWALS_ROOT: felt252 = 16;
const HEADER_GET_BLOB_GAS_USED: felt252 = 17;
const HEADER_GET_EXCESS_BLOB_GAS: felt252 = 18;
const HEADER_GET_PARENT_BEACON_BLOCK_ROOT: felt252 = 19;

#[derive(Serde, Drop)]
pub struct HeaderKey {
    pub chain_id: felt252,
    pub block_number: felt252,
}

#[generate_trait]
pub impl HeaderImpl of HeaderTrait {
    fn header_get_parent(self: @EvmMemorizer, key: @HeaderKey) -> u256 {
        let result = self.call_memorizer(HEADER_GET_PARENT, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn header_get_uncle(self: @EvmMemorizer, key: @HeaderKey) -> u256 {
        let result = self.call_memorizer(HEADER_GET_UNCLE, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn header_get_coinbase(self: @EvmMemorizer, key: @HeaderKey) -> u256 {
        let result = self.call_memorizer(HEADER_GET_COINBASE, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn header_get_state_root(self: @EvmMemorizer, key: @HeaderKey) -> u256 {
        let result = self.call_memorizer(HEADER_GET_STATE_ROOT, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn header_get_transaction_root(self: @EvmMemorizer, key: @HeaderKey) -> u256 {
        let result = self.call_memorizer(HEADER_GET_TRANSACTION_ROOT, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn header_get_receipt_root(self: @EvmMemorizer, key: @HeaderKey) -> u256 {
        let result = self.call_memorizer(HEADER_GET_RECEIPT_ROOT, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn header_get_difficulty(self: @EvmMemorizer, key: @HeaderKey) -> u256 {
        let result = self.call_memorizer(HEADER_GET_DIFFICULTY, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn header_get_number(self: @EvmMemorizer, key: @HeaderKey) -> u256 {
        let result = self.call_memorizer(HEADER_GET_NUMBER, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn header_get_gas_limit(self: @EvmMemorizer, key: @HeaderKey) -> u256 {
        let result = self.call_memorizer(HEADER_GET_GAS_LIMIT, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn header_get_gas_used(self: @EvmMemorizer, key: @HeaderKey) -> u256 {
        let result = self.call_memorizer(HEADER_GET_GAS_USED, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn header_get_timestamp(self: @EvmMemorizer, key: @HeaderKey) -> u256 {
        let result = self.call_memorizer(HEADER_GET_TIMESTAMP, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn header_get_mix_hash(self: @EvmMemorizer, key: @HeaderKey) -> u256 {
        let result = self.call_memorizer(HEADER_GET_MIX_HASH, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn header_get_nonce(self: @EvmMemorizer, key: @HeaderKey) -> u256 {
        let result = self.call_memorizer(HEADER_GET_NONCE, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn header_get_base_fee_per_gas(self: @EvmMemorizer, key: @HeaderKey) -> u256 {
        let result = self.call_memorizer(HEADER_GET_BASE_FEE_PER_GAS, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    // fn header_get_withdrawals_root(self: @EvmMemorizer, key: @HeaderKey) -> u256 {
    //     let result = self.call_memorizer(HEADER_GET_WITHDRAWALS_ROOT, key);
    //     u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    // }
    fn header_get_blob_gas_used(self: @EvmMemorizer, key: @HeaderKey) -> u256 {
        let result = self.call_memorizer(HEADER_GET_BLOB_GAS_USED, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn header_get_excess_blob_gas(self: @EvmMemorizer, key: @HeaderKey) -> u256 {
        let result = self.call_memorizer(HEADER_GET_EXCESS_BLOB_GAS, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    // fn header_get_parent_beacon_block_root(self: @EvmMemorizer, key: @HeaderKey) -> u256 {
    //     let result = self.call_memorizer(HEADER_GET_PARENT_BEACON_BLOCK_ROOT, key);
    //     u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    // }

    fn call_memorizer(self: @EvmMemorizer, selector: felt252, key: @HeaderKey) -> Span<felt252> {
        call_contract_syscall(
            HEADER.try_into().unwrap(),
            selector,
            array![*self.dict.segment_index, *self.dict.offset, *key.chain_id, *key.block_number]
                .span(),
        )
            .unwrap_syscall()
    }
}
