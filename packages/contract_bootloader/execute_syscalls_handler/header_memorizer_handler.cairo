from starkware.cairo.common.alloc import alloc
from src.decoders.header_decoder import HeaderDecoder, HeaderField
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.registers import get_label_location

// This is not used but stays for reference
namespace HeaderMemorizerFunctionId {
    const GET_PARENT = 0;
    const GET_UNCLE = 1;
    const GET_COINBASE = 2;
    const GET_STATE_ROOT = 3;
    const GET_TRANSACTION_ROOT = 4;
    const GET_RECEIPT_ROOT = 5;
    const GET_BLOOM = 6;
    const GET_DIFFICULTY = 7;
    const GET_NUMBER = 8;
    const GET_GAS_LIMIT = 9;
    const GET_GAS_USED = 10;
    const GET_TIMESTAMP = 11;
    const GET_EXTRA_DATA = 12;
    const GET_MIX_HASH = 13;
    const GET_NONCE = 14;
    const GET_BASE_FEE_PER_GAS = 15;
    const GET_WITHDRAWALS_ROOT = 16;
    const GET_BLOB_GAS_USED = 17;
    const GET_EXCESS_BLOB_GAS = 18;
    const GET_PARENT_BEACON_BLOCK_ROOT = 19;
}

func get_memorizer_handler_ptrs() -> felt** {
    let (handler_list) = alloc();
    let handler_ptrs = cast(handler_list, felt**);

    let (label) = get_label_location(get_parent_value);
    assert handler_ptrs[HeaderMemorizerFunctionId.GET_PARENT] = label;

    let (label) = get_label_location(get_uncle_value);
    assert handler_ptrs[HeaderMemorizerFunctionId.GET_UNCLE] = label;

    let (label) = get_label_location(get_coinbase_value);
    assert handler_ptrs[HeaderMemorizerFunctionId.GET_COINBASE] = label;

    let (label) = get_label_location(get_state_root_value);
    assert handler_ptrs[HeaderMemorizerFunctionId.GET_STATE_ROOT] = label;

    let (label) = get_label_location(get_transaction_root_value);
    assert handler_ptrs[HeaderMemorizerFunctionId.GET_TRANSACTION_ROOT] = label;

    let (label) = get_label_location(get_receipt_root_value);
    assert handler_ptrs[HeaderMemorizerFunctionId.GET_RECEIPT_ROOT] = label;

    assert handler_ptrs[HeaderMemorizerFunctionId.GET_BLOOM] = cast(0, felt*);

    let (label) = get_label_location(get_difficulty_value);
    assert handler_ptrs[HeaderMemorizerFunctionId.GET_DIFFICULTY] = label;

    let (label) = get_label_location(get_number_value);
    assert handler_ptrs[HeaderMemorizerFunctionId.GET_NUMBER] = label;

    let (label) = get_label_location(get_gas_limit_value);
    assert handler_ptrs[HeaderMemorizerFunctionId.GET_GAS_LIMIT] = label;

    let (label) = get_label_location(get_gas_used_value);
    assert handler_ptrs[HeaderMemorizerFunctionId.GET_GAS_USED] = label;

    let (label) = get_label_location(get_timestamp_value);
    assert handler_ptrs[HeaderMemorizerFunctionId.GET_TIMESTAMP] = label;

    let (label) = get_label_location(get_extra_data_value);
    assert handler_ptrs[HeaderMemorizerFunctionId.GET_EXTRA_DATA] = label;

    let (label) = get_label_location(get_mix_hash_value);
    assert handler_ptrs[HeaderMemorizerFunctionId.GET_MIX_HASH] = label;

    let (label) = get_label_location(get_nonce_value);
    assert handler_ptrs[HeaderMemorizerFunctionId.GET_NONCE] = label;

    let (label) = get_label_location(get_base_fee_per_gas_value);
    assert handler_ptrs[HeaderMemorizerFunctionId.GET_BASE_FEE_PER_GAS] = label;

    assert handler_ptrs[HeaderMemorizerFunctionId.GET_WITHDRAWALS_ROOT] = cast(0, felt*);
    assert handler_ptrs[HeaderMemorizerFunctionId.GET_BLOB_GAS_USED] = cast(0, felt*);
    assert handler_ptrs[HeaderMemorizerFunctionId.GET_EXCESS_BLOB_GAS] = cast(0, felt*);
    assert handler_ptrs[HeaderMemorizerFunctionId.GET_PARENT_BEACON_BLOCK_ROOT] = cast(0, felt*);

    return handler_ptrs;
}

func get_parent_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.PARENT);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func get_uncle_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.UNCLE);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func get_coinbase_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.COINBASE);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func get_state_root_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.STATE_ROOT);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func get_transaction_root_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.TRANSACTION_ROOT);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func get_receipt_root_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.RECEIPT_ROOT);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}
func get_difficulty_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.DIFFICULTY);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func get_number_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.NUMBER);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func get_gas_limit_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.GAS_LIMIT);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func get_gas_used_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.GAS_USED);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func get_timestamp_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.TIMESTAMP);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func get_extra_data_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.EXTRA_DATA);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func get_mix_hash_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.MIX_HASH);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func get_nonce_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.NONCE);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func get_base_fee_per_gas_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.BASE_FEE_PER_GAS);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}
