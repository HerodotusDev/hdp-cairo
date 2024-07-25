from src.decoders.header_decoder import HeaderDecoder, HeaderField
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

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

func header_memorizer_get_parent_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.PARENT);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_uncle_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.UNCLE);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_coinbase_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.COINBASE);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_state_root_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.STATE_ROOT);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_transaction_root_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.TRANSACTION_ROOT);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_receipt_root_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.RECEIPT_ROOT);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}
func header_memorizer_get_difficulty_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.DIFFICULTY);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_number_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.NUMBER);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_gas_limit_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.GAS_LIMIT);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_gas_used_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.GAS_USED);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_timestamp_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.TIMESTAMP);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_extra_data_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.EXTRA_DATA);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_mix_hash_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.MIX_HASH);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_nonce_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.NONCE);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_base_fee_per_gas_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.BASE_FEE_PER_GAS);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}
