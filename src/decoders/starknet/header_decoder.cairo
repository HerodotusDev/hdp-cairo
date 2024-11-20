from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.uint256 import Uint256, felt_to_uint256
from packages.eth_essentials.lib.utils import felt_divmod
from starkware.cairo.common.bitwise import bitwise_and

namespace StarknetHeaderVersion {
    const VERSION_1 = 0;
    const VERSION_2 = 1;
}

namespace StarknetHeaderFields {
    const BLOCK_NUMBER = 0;
    const STATE_ROOT = 1;
    const SEQUENCER_ADDRESS = 2;
    const BLOCK_TIMESTAMP = 3;
    const TRANSACTION_COUNT = 4;
    const TRANSACTION_COMMITMENT = 5;
    const EVENT_COUNT = 6;
    const EVENT_COMMITMENT = 7;
    const PARENT_BLOCK_HASH = 8;
    const STATE_DIFF_COMMITMENT = 9;
    const STATE_DIFF_LENGTH = 10;
    const L1_GAS_PRICE_IN_WEI = 11;
    const L1_GAS_PRICE_IN_FRI = 12;
    const L1_DATA_GAS_PRICE_IN_WEI = 13;
    const L1_DATA_GAS_PRICE_IN_FRI = 14;
    const RECEIPTS_COMMITMENT = 15;
    const L1_DATA_MODE = 16;
    const PROTOCOL_VERSION = 17;
}

namespace StarknetHeaderDecoder {
    func derive_header_version(fields: felt*) -> felt {
        // 0x535441524b4e45545f424c4f434b5f4841534830 = to_hex("STARKNET_BLOCK_HASH0")
        if (fields[1] == 0x535441524b4e45545f424c4f434b5f4841534830) {
            return StarknetHeaderVersion.VERSION_2;
        }

        return StarknetHeaderVersion.VERSION_1;
    }

    func get_field{range_check_ptr}(fields: felt*, field: felt) -> (value: felt) {
        // %{
        //     i = 0
        //     while i < 18:
        //         print("Field ", i, ": ", hex(memory[ids.fields + i]))
        //         i += 1

        // %}

        if (field == StarknetHeaderFields.TRANSACTION_COUNT) {
            assert 1 = 0;
            return (value=0);
        }

        if (field == StarknetHeaderFields.EVENT_COUNT) {
            assert 1 = 0;
            return (value=0);
        }

        if (field == StarknetHeaderFields.STATE_DIFF_LENGTH) {
            assert 1 = 0;
            return (value=0);
        }

        if (field == StarknetHeaderFields.L1_DATA_MODE) {
            assert 1 = 0;
            return (value=0);
        }

        %{ print("Requested field: ", ids.field); %}

        let version = derive_header_version(fields);
        let index = get_header_field_index(version, field);

        %{ print("Index: ", ids.index); %}

        // todo: handle len decoding for v2 headers
        return (value=fields[index]);
    }

    // func decode_concat_counts{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(value_concat: felt, field: felt) -> (value: felt) {
    //     if (field == StarknetHeaderFields.TRANSACTION_COUNT) {
    //         // Extract using TRANSACTION_COUNT_MASK and get first 64 bits
    //         let (masked) = bitwise_and(value_concat, TRANSACTION_COUNT_MASK);
    //         let (value, _) = felt_divmod(masked, 2**192);
    //         return (value=value);
    //     }

    // if (field == StarknetHeaderFields.EVENT_COUNT) {
    //         // Extract using EVENT_COUNT_MASK and get middle 64 bits
    //         let (masked) = bitwise_and(value_concat, EVENT_COUNT_MASK);
    //         let (value, _) = felt_divmod(masked, 2**128);
    //         return (value=value);
    //     }

    // if (field == StarknetHeaderFields.STATE_DIFF_LENGTH) {
    //         // Extract using STATE_DIFF_LENGTH_MASK and get next 64 bits
    //         let (masked) = bitwise_and(value_concat, STATE_DIFF_LENGTH_MASK);
    //         let (value, _) = felt_divmod(masked, 2**64);
    //         return (value=value);
    //     }

    // if (field == StarknetHeaderFields.L1_DATA_MODE) {
    //         // Extract using L1_DA_MODE_MASK and get last byte
    //         let (masked) = bitwise_and(value_concat, L1_DA_MODE_MASK);
    //         let (value, _) = felt_divmod(masked, 2**56);
    //         return (value=value);
    //     }
    // }

    func get_field_uint256{range_check_ptr}(fields: felt*, field: felt) -> Uint256 {
        let (felt_value) = get_field(fields, field);
        let value = felt_to_uint256(felt_value);
        return value;
    }

    func get_block_number{range_check_ptr}(fields: felt*) -> (value: felt) {
        return get_field(fields, StarknetHeaderFields.BLOCK_NUMBER);
    }
}

// V1_HEADER = [
// block_number,
// state_root,
// sequencer_address,
// block_timestamp,
// transaction_count,
// transaction_commitment,
// event_count,
// event_commitment,
// 0,
// 0,
// parent_block_hash
// ]

// V2_HEADER = [
// "STARKNET_BLOCK_HASH0",
// block_number,
// state_root,
// sequencer_address,
// block_timestamp,
// transaction_count || event_count || state_diff_length || l1_da_mode,
// state_diff_commitment,
// transactions_commitment
// events_commitment,
// receipts_commitment,
// l1_gas_price_in_wei,
// l1_gas_price_in_fri,
// l1_data_gas_price_in_wei,
// l1_data_gas_price_in_fri
// protocol_version
// 0,
// parent_block_hash
// ]

// Depending on the header version, the fields are located at different offsets in the data array.
// This function calculates the correct index of a field in the data array, depending on the version.
// When writing the verified header to the memorizer, we prefix the fields with its length to make it retrievable.
// For this reason, we increment the offset by 1
func get_header_field_index{range_check_ptr}(version: felt, field: felt) -> felt {
    alloc_locals;
    assert [range_check_ptr] = 17 - field;
    assert [range_check_ptr + 1] = 1 - version;
    tempvar range_check_ptr = range_check_ptr + 2;

    let (data_address) = get_label_location(data);
    local index = [data_address + field + (18 * version)];

    if (index == 0xFFFFFFFF) {
        // Field not available in this version
        assert 1 = 0;
    }

    return index;

    data:
    // VERSION_1 field indices
    dw 1;  // BLOCK_NUMBER
    dw 2;  // STATE_ROOT
    dw 3;  // SEQUENCER_ADDRESS
    dw 4;  // BLOCK_TIMESTAMP
    dw 5;  // TRANSACTION_COUNT
    dw 6;  // TRANSACTION_COMMITMENT
    dw 7;  // EVENT_COUNT
    dw 8;  // EVENT_COMMITMENT
    dw 11;  // PARENT_BLOCK_HASH
    dw 0xFFFFFFFF;  // STATE_DIFF_COMMITMENT
    dw 0xFFFFFFFF;  // STATE_DIFF_LENGTH
    dw 0xFFFFFFFF;  // L1_GAS_PRICE_IN_WEI
    dw 0xFFFFFFFF;  // L1_GAS_PRICE_IN_FRI
    dw 0xFFFFFFFF;  // L1_DATA_GAS_PRICE_IN_WEI
    dw 0xFFFFFFFF;  // L1_DATA_GAS_PRICE_IN_FRI
    dw 0xFFFFFFFF;  // RECEIPTS_COMMITMENT
    dw 0xFFFFFFFF;  // L1_DATA_MODE
    dw 0xFFFFFFFF;  // PROTOCOL_VERSION

    // VERSION_2 field indices
    dw 2;  // BLOCK_NUMBER
    dw 3;  // STATE_ROOT
    dw 4;  // SEQUENCER_ADDRESS
    dw 5;  // BLOCK_TIMESTAMP
    dw 6;  // TRANSACTION_COUNT
    dw 8;  // TRANSACTION_COMMITMENT
    dw 6;  // EVENT_COUNT
    dw 9;  // EVENT_COMMITMENT
    dw 17;  // PARENT_BLOCK_HASH
    dw 7;  // STATE_DIFF_COMMITMENT
    dw 6;  // STATE_DIFF_LENGTH
    dw 11;  // L1_GAS_PRICE_IN_WEI
    dw 12;  // L1_GAS_PRICE_IN_FRI
    dw 13;  // L1_DATA_GAS_PRICE_IN_WEI
    dw 14;  // L1_DATA_GAS_PRICE_IN_FRI
    dw 10;  // RECEIPTS_COMMITMENT
    dw 6;  // L1_DATA_MODE
    dw 15;  // PROTOCOL_VERSION
}
