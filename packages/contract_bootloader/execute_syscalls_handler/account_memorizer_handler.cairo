from src.decoders.account_decoder import AccountDecoder, AccountField
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian

account_memorizer_get_value:
dw get_label_location(account_memorizer_get_nonce_value);  // GET_NONCE = 0;
dw get_label_location(account_memorizer_get_balance_value);  // GET_BALANCE = 1;
dw get_label_location(account_memorizer_get_state_root_value);  // GET_STATE_ROOT = 2;
dw get_label_location(account_memorizer_get_code_hash_value);  // GET_CODE_HASH = 3;
dw 0;

func account_memorizer_get_nonce_value() -> Uint256 {
    let field: Uint256 = AccountDecoder.get_field(rlp=rlp, field=AccountField.NONCE);
    let (value) = uint256_reverse_endian(num=field);

    return value;
}

func account_memorizer_get_balance_value() -> Uint256 {
    let field: Uint256 = AccountDecoder.get_field(rlp=rlp, field=AccountField.BALANCE);
    let (value) = uint256_reverse_endian(num=field);

    return value;
}

func account_memorizer_get_state_root_value() -> Uint256 {
    let field: Uint256 = AccountDecoder.get_field(rlp=rlp, field=AccountField.STATE_ROOT);
    let (value) = uint256_reverse_endian(num=field);

    return value;
}

func account_memorizer_get_code_hash_value() -> Uint256 {
    let field: Uint256 = AccountDecoder.get_field(rlp=rlp, field=AccountField.CODE_HASH);
    let (value) = uint256_reverse_endian(num=field);

    return value;
}
