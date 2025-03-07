use hdp_cairo::EvmMemorizer;
use starknet::syscalls::call_contract_syscall;
use starknet::{SyscallResultTrait};

const BLOCK_RECEIPT: felt252 = 4;

const BLOCK_RECEIPT_GET_STATUS: felt252 = 0;
const BLOCK_RECEIPT_GET_CUMULATIVE_GAS_USED: felt252 = 1;
const BLOCK_RECEIPT_GET_BLOOM: felt252 = 2;

#[derive(Serde, Drop)]
pub struct BlockReceiptKey {
    pub chain_id: felt252,
    pub block_number: felt252,
    pub transaction_index: felt252,
}

#[generate_trait]
pub impl BlockReceiptImpl of BlockReceiptTrait {
    fn block_receipt_get_status(self: @EvmMemorizer, key: @BlockReceiptKey) -> u256 {
        let result = self.call_memorizer(BLOCK_RECEIPT_GET_STATUS, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn block_receipt_get_cumulative_gas_used(self: @EvmMemorizer, key: @BlockReceiptKey) -> u256 {
        let result = self.call_memorizer(BLOCK_RECEIPT_GET_CUMULATIVE_GAS_USED, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn block_receipt_get_bloom(self: @EvmMemorizer, key: @BlockReceiptKey) -> Array<u128> {
        let mut result: Array<u128> = array![];
        for element in self.call_memorizer(BLOCK_RECEIPT_GET_BLOOM, key) {
            result.append((*element).try_into().unwrap());
        };
        result
    }

    fn call_memorizer(
        self: @EvmMemorizer, selector: felt252, key: @BlockReceiptKey,
    ) -> Span<felt252> {
        call_contract_syscall(
            BLOCK_RECEIPT.try_into().unwrap(),
            selector,
            array![
                *self.dict.segment_index,
                *self.dict.offset,
                *key.chain_id,
                *key.block_number,
                *key.transaction_index,
            ]
                .span(),
        )
            .unwrap_syscall()
    }
}
