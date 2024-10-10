use hdp_cairo::Memorizer;
use starknet::syscalls::call_contract_syscall;
use starknet::{SyscallResult, SyscallResultTrait};

const BLOCK_TX_MEMORIZER: felt252 = 3;
const BLOCK_TX_MEMORIZER_GET_NONCE: felt252 = 0;
const BLOCK_TX_MEMORIZER_GET_GAS_PRICE: felt252 = 1;
const BLOCK_TX_MEMORIZER_GET_GAS_LIMIT: felt252 = 2;
const BLOCK_TX_MEMORIZER_GET_RECEIVER: felt252 = 3;
const BLOCK_TX_MEMORIZER_GET_VALUE: felt252 = 4;
const BLOCK_TX_MEMORIZER_GET_INPUT: felt252 = 5;
const BLOCK_TX_MEMORIZER_GET_V: felt252 = 6;
const BLOCK_TX_MEMORIZER_GET_R: felt252 = 7;
const BLOCK_TX_MEMORIZER_GET_S: felt252 = 8;
const BLOCK_TX_MEMORIZER_GET_CHAIN_ID: felt252 = 9;
const BLOCK_TX_MEMORIZER_GET_ACCESS_LIST: felt252 = 10;
const BLOCK_TX_MEMORIZER_GET_MAX_FEE_PER_GAS: felt252 = 11;
const BLOCK_TX_MEMORIZER_GET_MAX_PRIORITY_FEE_PER_GAS: felt252 = 12;
const BLOCK_TX_MEMORIZER_GET_BLOB_VERSIONED_HASHES: felt252 = 13;
const BLOCK_TX_MEMORIZER_GET_MAX_FEE_PER_BLOB_GAS: felt252 = 14;
const BLOCK_TX_MEMORIZER_GET_TX_TYPE: felt252 = 15;

#[derive(Serde, Drop)]
pub struct BlockTxKey {
    pub chain_id: felt252,
    pub block_number: felt252,
    pub index: felt252,
}

#[generate_trait]
pub impl BlockTxMemorizerImpl of BlockTxMemorizerTrait {
    fn get_nonce(self: @Memorizer, key: BlockTxKey) -> u256 {
        let value = call_contract_syscall(
            BLOCK_TX_MEMORIZER.try_into().unwrap(),
            BLOCK_TX_MEMORIZER_GET_NONCE,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number, key.index,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }

    fn get_gas_price(self: @Memorizer, key: BlockTxKey) -> u256 {
        let value = call_contract_syscall(
            BLOCK_TX_MEMORIZER.try_into().unwrap(),
            BLOCK_TX_MEMORIZER_GET_GAS_PRICE,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number, key.index,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }

    fn get_gas_limit(self: @Memorizer, key: BlockTxKey) -> u256 {
        let value = call_contract_syscall(
            BLOCK_TX_MEMORIZER.try_into().unwrap(),
            BLOCK_TX_MEMORIZER_GET_GAS_LIMIT,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number, key.index,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }

    fn get_receiver(self: @Memorizer, key: BlockTxKey) -> u256 {
        let value = call_contract_syscall(
            BLOCK_TX_MEMORIZER.try_into().unwrap(),
            BLOCK_TX_MEMORIZER_GET_RECEIVER,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number, key.index,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }

    fn get_value(self: @Memorizer, key: BlockTxKey) -> u256 {
        let value = call_contract_syscall(
            BLOCK_TX_MEMORIZER.try_into().unwrap(),
            BLOCK_TX_MEMORIZER_GET_VALUE,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number, key.index,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }

    fn get_input(self: @Memorizer, key: BlockTxKey) -> u256 {
        let value = call_contract_syscall(
            BLOCK_TX_MEMORIZER.try_into().unwrap(),
            BLOCK_TX_MEMORIZER_GET_INPUT,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number, key.index,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }

    fn get_v(self: @Memorizer, key: BlockTxKey) -> u256 {
        let value = call_contract_syscall(
            BLOCK_TX_MEMORIZER.try_into().unwrap(),
            BLOCK_TX_MEMORIZER_GET_V,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number, key.index,]
        
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap()}
    }

    fn get_r(self: @Memorizer, key: BlockTxKey) -> u256 {
        let value = call_contract_syscall(
            BLOCK_TX_MEMORIZER.try_into().unwrap(),
            BLOCK_TX_MEMORIZER_GET_R,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number, key.index,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }

    fn get_s(self: @Memorizer, key: BlockTxKey) -> u256 {
        let value = call_contract_syscall(
            BLOCK_TX_MEMORIZER.try_into().unwrap(),
            BLOCK_TX_MEMORIZER_GET_S,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number, key.index,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }

    fn get_chain_id(self: @Memorizer, key: BlockTxKey) -> u256 {
        let value = call_contract_syscall(
            BLOCK_TX_MEMORIZER.try_into().unwrap(),
            BLOCK_TX_MEMORIZER_GET_CHAIN_ID,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number, key.index,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }

    fn get_access_list(self: @Memorizer, key: BlockTxKey) -> u256 {
        let value = call_contract_syscall(
            BLOCK_TX_MEMORIZER.try_into().unwrap(),
            BLOCK_TX_MEMORIZER_GET_ACCESS_LIST,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number, key.index,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }

    fn get_max_fee_per_gas(self: @Memorizer, key: BlockTxKey) -> u256 {
        let value = call_contract_syscall(
            BLOCK_TX_MEMORIZER.try_into().unwrap(),
            BLOCK_TX_MEMORIZER_GET_MAX_FEE_PER_GAS,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number, key.index,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }

    fn get_max_priority_fee_per_gas(self: @Memorizer, key: BlockTxKey) -> u256 {
        let value = call_contract_syscall(
            BLOCK_TX_MEMORIZER.try_into().unwrap(),
            BLOCK_TX_MEMORIZER_GET_MAX_PRIORITY_FEE_PER_GAS,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number, key.index,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }

    fn get_blob_versioned_hashes(self: @Memorizer, key: BlockTxKey) -> u256 {
        let value = call_contract_syscall(
            BLOCK_TX_MEMORIZER.try_into().unwrap(),
            BLOCK_TX_MEMORIZER_GET_BLOB_VERSIONED_HASHES,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number, key.index,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }

    fn get_max_fee_per_blob_gas(self: @Memorizer, key: BlockTxKey) -> u256 {
        let value = call_contract_syscall(
            BLOCK_TX_MEMORIZER.try_into().unwrap(),
            BLOCK_TX_MEMORIZER_GET_MAX_FEE_PER_BLOB_GAS,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number, key.index,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }

    fn get_tx_type(self: @Memorizer, key: BlockTxKey) -> u256 {
        let value = call_contract_syscall(
            BLOCK_TX_MEMORIZER.try_into().unwrap(),
            BLOCK_TX_MEMORIZER_GET_TX_TYPE,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number, key.index,]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
}