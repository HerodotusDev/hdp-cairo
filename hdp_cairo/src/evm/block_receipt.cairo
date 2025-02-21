use hdp_cairo::EvmMemorizer;
use starknet::syscalls::call_contract_syscall;
use starknet::{SyscallResultTrait};

const BLOCK_RECEIPT: felt252 = 4;

const BLOCK_RECEIPT_GET_STATUS: felt252 = 0;
const BLOCK_RECEIPT_GET_CUMULATIVE_GAS_USED: felt252 = 1;
const BLOCK_RECEIPT_GET_BLOOM: felt252 = 2;
const BLOCK_RECEIPT_GET_TOPIC0: felt252 = 3;
const BLOCK_RECEIPT_GET_TOPIC1: felt252 = 4;
const BLOCK_RECEIPT_GET_TOPIC2: felt252 = 5;
const BLOCK_RECEIPT_GET_TOPIC3: felt252 = 6;
const BLOCK_RECEIPT_GET_TOPIC4: felt252 = 7;
const BLOCK_RECEIPT_GET_DATA: felt252 = 8;

const BLOCK_RECEIPT_LABEL: felt252 = 'block_receipt';

#[derive(Serde, Drop)]
pub struct BlockReceiptKey {
    pub chain_id: felt252,
    pub block_number: felt252,
    pub transaction_index: felt252,
}

#[generate_trait]
pub impl BlockReceiptImpl of BlockReceiptTrait {
    fn block_receipt_get_status(self: @EvmMemorizer, key: BlockReceiptKey) -> u256 {
        let result = self.call_memorizer(BLOCK_RECEIPT_GET_STATUS, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn block_receipt_get_cumulative_gas_used(self: @EvmMemorizer, key: BlockReceiptKey) -> u256 {
        let result = self.call_memorizer(BLOCK_RECEIPT_GET_CUMULATIVE_GAS_USED, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn block_receipt_get_bloom(self: @EvmMemorizer, key: BlockReceiptKey) -> u256 {
        let result = self.call_memorizer(BLOCK_RECEIPT_GET_BLOOM, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn block_receipt_get_topic0(self: @EvmMemorizer, key: BlockReceiptKey) -> u256 {
        let result = self.call_memorizer(BLOCK_RECEIPT_GET_TOPIC0, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn block_receipt_get_topic1(self: @EvmMemorizer, key: BlockReceiptKey) -> u256 {
        let result = self.call_memorizer(BLOCK_RECEIPT_GET_TOPIC1, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn block_receipt_get_topic2(self: @EvmMemorizer, key: BlockReceiptKey) -> u256 {
        let result = self.call_memorizer(BLOCK_RECEIPT_GET_TOPIC2, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn block_receipt_get_topic3(self: @EvmMemorizer, key: BlockReceiptKey) -> u256 {
        let result = self.call_memorizer(BLOCK_RECEIPT_GET_TOPIC3, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn block_receipt_get_topic4(self: @EvmMemorizer, key: BlockReceiptKey) -> u256 {
        let result = self.call_memorizer(BLOCK_RECEIPT_GET_TOPIC4, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn block_receipt_get_data(self: @EvmMemorizer, key: BlockReceiptKey) -> Span<felt252> {
        self.call_memorizer(BLOCK_RECEIPT_GET_DATA, key)
    }

    fn call_memorizer(
        self: @EvmMemorizer, selector: felt252, key: BlockReceiptKey,
    ) -> Span<felt252> {
        call_contract_syscall(
            BLOCK_RECEIPT.try_into().unwrap(),
            selector,
            array![
                *self.dict.segment_index,
                *self.dict.offset,
                key.chain_id,
                BLOCK_RECEIPT_LABEL,
                key.block_number,
                key.transaction_index,
            ]
                .span(),
        )
            .unwrap_syscall()
    }
}
