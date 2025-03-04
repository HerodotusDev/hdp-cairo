use hdp_cairo::EvmMemorizer;
use starknet::syscalls::call_contract_syscall;
use starknet::{SyscallResultTrait};

const LOG: felt252 = 5;

const LOG_GET_ADDRESS: felt252 = 0;
const LOG_GET_TOPIC0: felt252 = 1;
const LOG_GET_TOPIC1: felt252 = 2;
const LOG_GET_TOPIC2: felt252 = 3;
const LOG_GET_TOPIC3: felt252 = 4;
const LOG_GET_TOPIC4: felt252 = 5;
const LOG_GET_DATA: felt252 = 6;

#[derive(Serde, Drop)]
pub struct LogKey {
    pub chain_id: felt252,
    pub block_number: felt252,
    pub transaction_index: felt252,
    pub log_index: felt252,
}

#[generate_trait]
pub impl LogImpl of LogTrait {
    fn log_get_address(self: @EvmMemorizer, key: @LogKey) -> u256 {
        let result = self.call_memorizer(LOG_GET_ADDRESS, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn log_get_topic0(self: @EvmMemorizer, key: @LogKey) -> u256 {
        let result = self.call_memorizer(LOG_GET_TOPIC0, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn log_get_topic1(self: @EvmMemorizer, key: @LogKey) -> u256 {
        let result = self.call_memorizer(LOG_GET_TOPIC1, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn log_get_topic2(self: @EvmMemorizer, key: @LogKey) -> u256 {
        let result = self.call_memorizer(LOG_GET_TOPIC2, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn log_get_topic3(self: @EvmMemorizer, key: @LogKey) -> u256 {
        let result = self.call_memorizer(LOG_GET_TOPIC3, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn log_get_topic4(self: @EvmMemorizer, key: @LogKey) -> u256 {
        let result = self.call_memorizer(LOG_GET_TOPIC4, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn log_get_data(self: @EvmMemorizer, key: @LogKey) -> Array<u128> {
        let mut result: Array<u128> = array![];
        for element in self.call_memorizer(LOG_GET_DATA, key) {
            result.append((*element).try_into().unwrap());
        };
        result
    }

    fn call_memorizer(self: @EvmMemorizer, selector: felt252, key: @LogKey) -> Span<felt252> {
        call_contract_syscall(
            LOG.try_into().unwrap(),
            selector,
            array![
                *self.dict.segment_index,
                *self.dict.offset,
                *key.chain_id,
                *key.block_number,
                *key.transaction_index,
                *key.log_index,
            ]
                .span(),
        )
            .unwrap_syscall()
    }
}
