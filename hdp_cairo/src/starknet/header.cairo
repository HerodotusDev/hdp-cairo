use hdp_cairo::StarknetMemorizer;
use starknet::syscalls::call_contract_syscall;
use starknet::{SyscallResultTrait};

const HEADER: felt252 = 0;

// Function selectors matching StarknetStateFunctionId from Python
const HEADER_GET_BLOCK_NUMBER: felt252 = 0;
const HEADER_GET_STATE_ROOT: felt252 = 1;
const HEADER_GET_SEQUENCER_ADDRESS: felt252 = 2;
const HEADER_GET_BLOCK_TIMESTAMP: felt252 = 3;
const HEADER_GET_TRANSACTION_COUNT: felt252 = 4;
const HEADER_GET_TRANSACTION_COMMITMENT: felt252 = 5;
const HEADER_GET_EVENT_COUNT: felt252 = 6;
const HEADER_GET_EVENT_COMMITMENT: felt252 = 7;
const HEADER_GET_PARENT_BLOCK_HASH: felt252 = 8;
const HEADER_GET_STATE_DIFF_COMMITMENT: felt252 = 9;
const HEADER_GET_STATE_DIFF_LENGTH: felt252 = 10;
const HEADER_GET_L1_GAS_PRICE_IN_WEI: felt252 = 11;
const HEADER_GET_L1_GAS_PRICE_IN_FRI: felt252 = 12;
const HEADER_GET_L1_DATA_GAS_PRICE_IN_WEI: felt252 = 13;
const HEADER_GET_L1_DATA_GAS_PRICE_IN_FRI: felt252 = 14;
const HEADER_GET_RECEIPTS_COMMITMENT: felt252 = 15;
const HEADER_GET_L1_DATA_MODE: felt252 = 16;
const HEADER_GET_PROTOCOL_VERSION: felt252 = 17;

#[derive(Serde, Drop)]
pub struct HeaderKey {
    pub chain_id: felt252,
    pub block_number: felt252,
}

#[generate_trait]
pub impl HeaderImpl of HeaderTrait {
    fn header_get_block_number(self: @StarknetMemorizer, key: HeaderKey) -> felt252 {
        self.call_memorizer(HEADER_GET_BLOCK_NUMBER, key)
    }

    fn header_get_state_root(self: @StarknetMemorizer, key: HeaderKey) -> felt252 {
        self.call_memorizer(HEADER_GET_STATE_ROOT, key)
    }

    fn header_get_sequencer_address(self: @StarknetMemorizer, key: HeaderKey) -> felt252 {
        self.call_memorizer(HEADER_GET_SEQUENCER_ADDRESS, key)
    }

    fn header_get_block_timestamp(self: @StarknetMemorizer, key: HeaderKey) -> felt252 {
        self.call_memorizer(HEADER_GET_BLOCK_TIMESTAMP, key)
    }

    fn header_get_transaction_count(self: @StarknetMemorizer, key: HeaderKey) -> felt252 {
        self.call_memorizer(HEADER_GET_TRANSACTION_COUNT, key)
    }

    fn header_get_transaction_commitment(self: @StarknetMemorizer, key: HeaderKey) -> felt252 {
        self.call_memorizer(HEADER_GET_TRANSACTION_COMMITMENT, key)
    }

    fn header_get_event_count(self: @StarknetMemorizer, key: HeaderKey) -> felt252 {
        self.call_memorizer(HEADER_GET_EVENT_COUNT, key)
    }

    fn header_get_event_commitment(self: @StarknetMemorizer, key: HeaderKey) -> felt252 {
        self.call_memorizer(HEADER_GET_EVENT_COMMITMENT, key)
    }

    fn header_get_parent_block_hash(self: @StarknetMemorizer, key: HeaderKey) -> felt252 {
        self.call_memorizer(HEADER_GET_PARENT_BLOCK_HASH, key)
    }

    fn header_get_state_diff_commitment(self: @StarknetMemorizer, key: HeaderKey) -> felt252 {
        self.call_memorizer(HEADER_GET_STATE_DIFF_COMMITMENT, key)
    }

    fn header_get_state_diff_length(self: @StarknetMemorizer, key: HeaderKey) -> felt252 {
        self.call_memorizer(HEADER_GET_STATE_DIFF_LENGTH, key)
    }

    fn header_get_l1_gas_price_in_wei(self: @StarknetMemorizer, key: HeaderKey) -> felt252 {
        self.call_memorizer(HEADER_GET_L1_GAS_PRICE_IN_WEI, key)
    }

    fn header_get_l1_gas_price_in_fri(self: @StarknetMemorizer, key: HeaderKey) -> felt252 {
        self.call_memorizer(HEADER_GET_L1_GAS_PRICE_IN_FRI, key)
    }

    fn header_get_l1_data_gas_price_in_wei(self: @StarknetMemorizer, key: HeaderKey) -> felt252 {
        self.call_memorizer(HEADER_GET_L1_DATA_GAS_PRICE_IN_WEI, key)
    }

    fn header_get_l1_data_gas_price_in_fri(self: @StarknetMemorizer, key: HeaderKey) -> felt252 {
        self.call_memorizer(HEADER_GET_L1_DATA_GAS_PRICE_IN_FRI, key)
    }

    fn header_get_receipts_commitment(self: @StarknetMemorizer, key: HeaderKey) -> felt252 {
        self.call_memorizer(HEADER_GET_RECEIPTS_COMMITMENT, key)
    }

    fn header_get_l1_data_mode(self: @StarknetMemorizer, key: HeaderKey) -> felt252 {
        self.call_memorizer(HEADER_GET_L1_DATA_MODE, key)
    }

    fn header_get_protocol_version(self: @StarknetMemorizer, key: HeaderKey) -> felt252 {
        self.call_memorizer(HEADER_GET_PROTOCOL_VERSION, key)
    }

    fn call_memorizer(self: @StarknetMemorizer, selector: felt252, key: HeaderKey) -> felt252 {
        let value = call_contract_syscall(
            HEADER.try_into().unwrap(),
            selector,
            array![*self.dict.segment_index, *self.dict.offset, key.chain_id, key.block_number]
                .span(),
        )
            .unwrap_syscall();
        (*value[0]).try_into().unwrap()
    }
}
