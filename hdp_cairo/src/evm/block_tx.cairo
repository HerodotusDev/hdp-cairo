use hdp_cairo::EvmMemorizer;
use starknet::syscalls::call_contract_syscall;
use starknet::{SyscallResultTrait};

const BLOCK_TX: felt252 = 3;

const BLOCK_TX_GET_NONCE: felt252 = 0;
const BLOCK_TX_GET_GAS_PRICE: felt252 = 1;
const BLOCK_TX_GET_GAS_LIMIT: felt252 = 2;
const BLOCK_TX_GET_RECEIVER: felt252 = 3;
const BLOCK_TX_GET_VALUE: felt252 = 4;
const BLOCK_TX_GET_INPUT: felt252 = 5;
const BLOCK_TX_GET_V: felt252 = 6;
const BLOCK_TX_GET_R: felt252 = 7;
const BLOCK_TX_GET_S: felt252 = 8;
const BLOCK_TX_GET_CHAIN_ID: felt252 = 9;
const BLOCK_TX_GET_ACCESS_LIST: felt252 = 10;
const BLOCK_TX_GET_MAX_FEE_PER_GAS: felt252 = 11;
const BLOCK_TX_GET_MAX_PRIORITY_FEE_PER_GAS: felt252 = 12;
const BLOCK_TX_GET_MAX_FEE_PER_BLOB_GAS: felt252 = 13;
const BLOCK_TX_GET_BLOB_VERSIONED_HASHES: felt252 = 14;
const BLOCK_TX_GET_TX_TYPE: felt252 = 15;
const BLOCK_TX_GET_SENDER: felt252 = 16;
const BLOCK_TX_GET_HASH: felt252 = 17;

#[derive(Serde, Drop)]
pub struct BlockTxKey {
    pub chain_id: felt252,
    pub block_number: felt252,
    pub transaction_index: felt252,
}

pub enum TxType {
    Legacy,
    Eip155,
    Eip2930,
    Eip1559,
    Eip4844,
    Eip7702,
}

#[generate_trait]
pub impl BlockTxImpl of BlockTxTrait {
    fn block_tx_get_nonce(self: @EvmMemorizer, key: BlockTxKey) -> u256 {
        self.call_memorizer(BLOCK_TX_GET_NONCE, key)
    }

    fn block_tx_get_gas_price(self: @EvmMemorizer, key: BlockTxKey) -> u256 {
        self.call_memorizer(BLOCK_TX_GET_GAS_PRICE, key)
    }

    fn block_tx_get_gas_limit(self: @EvmMemorizer, key: BlockTxKey) -> u256 {
        self.call_memorizer(BLOCK_TX_GET_GAS_LIMIT, key)
    }

    fn block_tx_get_receiver(self: @EvmMemorizer, key: BlockTxKey) -> u256 {
        self.call_memorizer(BLOCK_TX_GET_RECEIVER, key)
    }

    fn block_tx_get_value(self: @EvmMemorizer, key: BlockTxKey) -> u256 {
        self.call_memorizer(BLOCK_TX_GET_VALUE, key)
    }

    fn block_tx_get_v(self: @EvmMemorizer, key: BlockTxKey) -> u256 {
        self.call_memorizer(BLOCK_TX_GET_V, key)
    }

    fn block_tx_get_r(self: @EvmMemorizer, key: BlockTxKey) -> u256 {
        self.call_memorizer(BLOCK_TX_GET_R, key)
    }

    fn block_tx_get_s(self: @EvmMemorizer, key: BlockTxKey) -> u256 {
        self.call_memorizer(BLOCK_TX_GET_S, key)
    }

    fn block_tx_get_chain_id(self: @EvmMemorizer, key: BlockTxKey) -> u256 {
        self.call_memorizer(BLOCK_TX_GET_CHAIN_ID, key)
    }

    fn block_tx_get_max_fee_per_gas(self: @EvmMemorizer, key: BlockTxKey) -> u256 {
        self.call_memorizer(BLOCK_TX_GET_MAX_FEE_PER_GAS, key)
    }

    fn block_tx_get_max_priority_fee_per_gas(self: @EvmMemorizer, key: BlockTxKey) -> u256 {
        self.call_memorizer(BLOCK_TX_GET_MAX_PRIORITY_FEE_PER_GAS, key)
    }

    fn block_tx_get_max_fee_per_blob_gas(self: @EvmMemorizer, key: BlockTxKey) -> u256 {
        self.call_memorizer(BLOCK_TX_GET_MAX_FEE_PER_BLOB_GAS, key)
    }

    fn block_tx_get_tx_type(self: @EvmMemorizer, key: BlockTxKey) -> u256 {
        self.call_memorizer(BLOCK_TX_GET_TX_TYPE, key)
    }

    fn block_tx_get_sender(self: @EvmMemorizer, key: BlockTxKey) -> u256 {
        self.call_memorizer(BLOCK_TX_GET_SENDER, key)
    }

    fn block_tx_get_hash(self: @EvmMemorizer, key: BlockTxKey) -> u256 {
        self.call_memorizer(BLOCK_TX_GET_HASH, key)
    }

    fn call_memorizer(self: @EvmMemorizer, selector: felt252, key: BlockTxKey) -> u256 {
        let value = call_contract_syscall(
            BLOCK_TX.try_into().unwrap(),
            selector,
            array![
                *self.dict.segment_index,
                *self.dict.offset,
                key.chain_id,
                'block_tx',
                key.block_number,
                key.transaction_index,
            ]
                .span(),
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
}
