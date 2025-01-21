from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.uint256 import Uint256, felt_to_uint256
from packages.eth_essentials.lib.utils import bitwise_divmod
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

    func get_field{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(fields: felt*, field: felt) -> (value: felt) {

        let version = derive_header_version(fields);
        let index = get_header_field_index(version, field);

        if (field == StarknetHeaderFields.TRANSACTION_COUNT) {
            return decode_concat_counts(fields[index], field);
        }

        if (field == StarknetHeaderFields.EVENT_COUNT) {
            return decode_concat_counts(fields[index], field);
        }

        if (field == StarknetHeaderFields.STATE_DIFF_LENGTH) {
            return decode_concat_counts(fields[index], field);
        }

        if (field == StarknetHeaderFields.L1_DATA_MODE) {
            return decode_concat_counts(fields[index], field);
        }

        return (value=fields[index]);
    }

    func decode_concat_counts{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(value_concat: felt, field: felt) -> (value: felt) {

        if (field == StarknetHeaderFields.TRANSACTION_COUNT) {
            let (value, _) = bitwise_divmod(value_concat, pow2_array[192]);
            print_felt(value);
            return (value=value);
        }

        if (field == StarknetHeaderFields.EVENT_COUNT) {
            let (_, remainder) = bitwise_divmod(value_concat, pow2_array[192]);
            let (value, _) = bitwise_divmod(remainder, pow2_array[128]);
            print_felt(value);
            return (value=value);
        }

        if (field == StarknetHeaderFields.STATE_DIFF_LENGTH) {
            let (_, remainder) = bitwise_divmod(value_concat, pow2_array[128]);
            let (value, _) = bitwise_divmod(remainder, pow2_array[64]);
            return (value=value);
        }

        if (field == StarknetHeaderFields.L1_DATA_MODE) {
            let (_, remainder) = bitwise_divmod(value_concat, pow2_array[64]);

            let (msb_check, _) = bitwise_divmod(remainder, 2 ** 7);
            if (msb_check == 1) {
                return (value=0x1); // BLOB mode
            }
            return (value=0); // CALLDATA mode
        }

        // Should never reach here
        assert 1 = 0;
        return (value=0);
    }

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