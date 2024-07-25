from starkware.cairo.common.alloc import alloc
from src.decoders.account_decoder import AccountDecoder, AccountField
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.registers import get_label_location

// This is not used but stays for reference
namespace AccountMemorizerFunctionId {
    const GET_NONCE = 0;
    const GET_BALANCE = 1;
    const GET_STATE_ROOT = 2;
    const GET_CODE_HASH = 3;
}

func get_memorizer_handler_ptrs() -> felt** {
    let (handler_list) = alloc();
    let handler_ptrs = cast(handler_list, felt**);

    let (label) = get_label_location(get_nonce_value);
    assert handler_ptrs[AccountMemorizerFunctionId.GET_NONCE] = label;

    let (label) = get_label_location(get_balance_value);
    assert handler_ptrs[AccountMemorizerFunctionId.GET_BALANCE] = label;

    let (label) = get_label_location(get_state_root_value);
    assert handler_ptrs[AccountMemorizerFunctionId.GET_STATE_ROOT] = label;

    let (label) = get_label_location(get_code_hash_value);
    assert handler_ptrs[AccountMemorizerFunctionId.GET_CODE_HASH] = label;

    return handler_ptrs;
}

func get_nonce_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = AccountDecoder.get_field(rlp=rlp, field=AccountField.NONCE);
    let (value) = uint256_reverse_endian(num=field);

    return value;
}

func get_balance_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = AccountDecoder.get_field(rlp=rlp, field=AccountField.BALANCE);
    let (value) = uint256_reverse_endian(num=field);

    return value;
}

func get_state_root_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = AccountDecoder.get_field(rlp=rlp, field=AccountField.STATE_ROOT);
    let (value) = uint256_reverse_endian(num=field);

    return value;
}

func get_code_hash_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let field: Uint256 = AccountDecoder.get_field(rlp=rlp, field=AccountField.CODE_HASH);
    let (value) = uint256_reverse_endian(num=field);

    return value;
}
