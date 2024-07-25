from src.decoders.account_decoder import AccountDecoder, AccountField
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

// This is not used but stays for reference
namespace AccountMemorizerFunctionId {
    const GET_NONCE = 0;
    const GET_BALANCE = 1;
    const GET_STATE_ROOT = 2;
    const GET_CODE_HASH = 3;
}

func account_memorizer_get_nonce_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = AccountDecoder.get_field(rlp=rlp, field=AccountField.NONCE);
    let (value) = uint256_reverse_endian(num=field);

    return value;
}

func account_memorizer_get_balance_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = AccountDecoder.get_field(rlp=rlp, field=AccountField.BALANCE);
    let (value) = uint256_reverse_endian(num=field);

    return value;
}

func account_memorizer_get_state_root_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = AccountDecoder.get_field(rlp=rlp, field=AccountField.STATE_ROOT);
    let (value) = uint256_reverse_endian(num=field);

    return value;
}

func account_memorizer_get_code_hash_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = AccountDecoder.get_field(rlp=rlp, field=AccountField.CODE_HASH);
    let (value) = uint256_reverse_endian(num=field);

    return value;
}
