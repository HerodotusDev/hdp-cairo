from src.decoders.header_decoder import HeaderDecoder, HeaderField
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian

header_memorizer_get_value:
dw get_label_location(header_memorizer_get_parent_value);  // GET_PARENT = 0;
dw get_label_location(header_memorizer_get_uncle_value);  // GET_UNCLE = 1;
dw get_label_location(header_memorizer_get_coinbase_value);  // GET_COINBASE = 2;
dw get_label_location(header_memorizer_get_state_root_value);  // GET_STATE_ROOT = 3;
dw get_label_location(header_memorizer_get_transaction_root_value);  // GET_TRANSACTION_ROOT = 4;
dw get_label_location(header_memorizer_get_receipt_root_value);  // GET_RECEIPT_ROOT = 5;
dw get_label_location(header_memorizer_get_difficulty_value);  // GET_DIFFICULTY = 7;
dw get_label_location(header_memorizer_get_number_value);  // GET_NUMBER = 8;
dw get_label_location(header_memorizer_get_gas_limit_value);  // GET_GAS_LIMIT = 9;
dw get_label_location(header_memorizer_get_gas_used_value);  // GET_GAS_USED = 10;
dw get_label_location(header_memorizer_get_timestamp_value);  // GET_TIMESTAMP = 11;
dw get_label_location(header_memorizer_get_extra_data_value);  // GET_EXTRA_DATA = 12;
dw get_label_location(header_memorizer_get_mix_hash_value);  // GET_MIX_HASH = 13;
dw get_label_location(header_memorizer_get_nonce_value);  // GET_NONCE = 14;
dw get_label_location(header_memorizer_get_base_fee_per_gas_value);  // GET_BASE_FEE_PER_GAS = 15;
dw 0;

func header_memorizer_get_parent_value() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.PARENT);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_uncle_value() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.UNCLE);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_coinbase_value() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.COINBASE);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_state_root_value() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.STATE_ROOT);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_transaction_root_value() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.TRANSACTION_ROOT);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_receipt_root_value() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.RECEIPT_ROOT);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}
func header_memorizer_get_difficulty_value() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.DIFFICULTY);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_number_value() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.NUMBER);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_gas_limit_value() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.GAS_LIMIT);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_gas_used_value() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.GAS_USED);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_timestamp_value() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.TIMESTAMP);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_extra_data_value() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.EXTRA_DATA);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_mix_hash_value() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.MIX_HASH);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_nonce_value() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.NONCE);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}

func header_memorizer_get_base_fee_per_gas_value() -> Uint256 {
    let field: Uint256 = HeaderDecoder.get_field(rlp=rlp, field=HeaderField.BASE_FEE_PER_GAS);
    let (value) = uint256_reverse_endian(num=field);
    return value;
}
