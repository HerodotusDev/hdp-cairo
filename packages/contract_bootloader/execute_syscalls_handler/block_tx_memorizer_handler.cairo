from starkware.cairo.common.alloc import alloc
from src.decoders.transaction_decoder import TransactionDecoder, TransactionField
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.registers import get_label_location

// This is not used but stays for reference
namespace BlockTxMemorizerFunctionId {
    const GET_NONCE = 0;
    const GET_GAS_PRICE = 1;
    const GET_GAS_LIMIT = 2;
    const GET_RECEIVER = 3;
    const GET_VALUE = 4;
    const GET_INPUT = 5;
    const GET_V = 6;
    const GET_R = 7;
    const GET_S = 8;
    const GET_CHAIN_ID = 9;
    const GET_ACCESS_LIST = 10;
    const GET_MAX_FEE_PER_GAS = 11;
    const GET_MAX_PRIORITY_FEE_PER_GAS = 12;
    const GET_BLOB_VERSIONED_HASHES = 13;
    const GET_MAX_FEE_PER_BLOB_GAS = 14;
    const GET_TX_TYPE = 15;
}

func get_memorizer_handler_ptrs() -> felt** {
    let (handler_list) = alloc();
    let handler_ptrs = cast(handler_list, felt**);

    let (label) = get_label_location(get_nonce_value);
    assert handler_ptrs[BlockTxMemorizerFunctionId.GET_NONCE] = label;

    let (label) = get_label_location(get_gas_price_value);
    assert handler_ptrs[BlockTxMemorizerFunctionId.GET_GAS_PRICE] = label;

    let (label) = get_label_location(get_gas_limit_value);
    assert handler_ptrs[BlockTxMemorizerFunctionId.GET_GAS_LIMIT] = label;

    let (label) = get_label_location(get_receiver_value);
    assert handler_ptrs[BlockTxMemorizerFunctionId.GET_RECEIVER] = label;

    let (label) = get_label_location(get_value_value);
    assert handler_ptrs[BlockTxMemorizerFunctionId.GET_VALUE] = label;

    let (label) = get_label_location(get_input_value);
    assert handler_ptrs[BlockTxMemorizerFunctionId.GET_INPUT] = label;

    let (label) = get_label_location(get_v_value);
    assert handler_ptrs[BlockTxMemorizerFunctionId.GET_V] = label;

    let (label) = get_label_location(get_r_value);
    assert handler_ptrs[BlockTxMemorizerFunctionId.GET_R] = label;

    let (label) = get_label_location(get_s_value);
    assert handler_ptrs[BlockTxMemorizerFunctionId.GET_S] = label;

    let (label) = get_label_location(get_chain_id_value);
    assert handler_ptrs[BlockTxMemorizerFunctionId.GET_CHAIN_ID] = label;

    let (label) = get_label_location(get_access_list_value);
    assert handler_ptrs[BlockTxMemorizerFunctionId.GET_ACCESS_LIST] = label;

    let (label) = get_label_location(get_max_fee_per_gas_value);
    assert handler_ptrs[BlockTxMemorizerFunctionId.GET_MAX_FEE_PER_GAS] = label;

    let (label) = get_label_location(get_max_priority_fee_per_gas_value);
    assert handler_ptrs[BlockTxMemorizerFunctionId.GET_MAX_PRIORITY_FEE_PER_GAS] = label;

    let (label) = get_label_location(get_blob_versioned_hashes_value);
    assert handler_ptrs[BlockTxMemorizerFunctionId.GET_BLOB_VERSIONED_HASHES] = label;

    let (label) = get_label_location(get_max_fee_per_blob_gas_value);
    assert handler_ptrs[BlockTxMemorizerFunctionId.GET_MAX_FEE_PER_BLOB_GAS] = label;

    let (label) = get_label_location(get_tx_type_value);
    assert handler_ptrs[BlockTxMemorizerFunctionId.GET_TX_TYPE] = label;

    return handler_ptrs;
}

func get_nonce_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let (tx_type, rlp_start_offset) = TransactionDecoder.open_tx_envelope(item=rlp);

    let value = TransactionDecoder.get_field(
        rlp=rlp, field=TransactionField.NONCE, rlp_start_offset=rlp_start_offset, tx_type=tx_type
    );

    return value;
}

func get_gas_price_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let (tx_type, rlp_start_offset) = TransactionDecoder.open_tx_envelope(item=rlp);

    let value = TransactionDecoder.get_field(
        rlp=rlp,
        field=TransactionField.GAS_PRICE,
        rlp_start_offset=rlp_start_offset,
        tx_type=tx_type,
    );

    return value;
}

func get_gas_limit_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let (tx_type, rlp_start_offset) = TransactionDecoder.open_tx_envelope(item=rlp);

    let value = TransactionDecoder.get_field(
        rlp=rlp,
        field=TransactionField.GAS_LIMIT,
        rlp_start_offset=rlp_start_offset,
        tx_type=tx_type,
    );

    return value;
}

func get_receiver_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let (tx_type, rlp_start_offset) = TransactionDecoder.open_tx_envelope(item=rlp);

    let value = TransactionDecoder.get_field(
        rlp=rlp, field=TransactionField.RECEIVER, rlp_start_offset=rlp_start_offset, tx_type=tx_type
    );

    return value;
}

func get_value_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let (tx_type, rlp_start_offset) = TransactionDecoder.open_tx_envelope(item=rlp);

    let value = TransactionDecoder.get_field(
        rlp=rlp, field=TransactionField.VALUE, rlp_start_offset=rlp_start_offset, tx_type=tx_type
    );

    return value;
}

func get_input_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let (tx_type, rlp_start_offset) = TransactionDecoder.open_tx_envelope(item=rlp);

    let value = TransactionDecoder.get_field(
        rlp=rlp, field=TransactionField.INPUT, rlp_start_offset=rlp_start_offset, tx_type=tx_type
    );

    return value;
}

func get_v_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let (tx_type, rlp_start_offset) = TransactionDecoder.open_tx_envelope(item=rlp);

    let value = TransactionDecoder.get_field(
        rlp=rlp, field=TransactionField.V, rlp_start_offset=rlp_start_offset, tx_type=tx_type
    );

    return value;
}

func get_r_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let (tx_type, rlp_start_offset) = TransactionDecoder.open_tx_envelope(item=rlp);

    let value = TransactionDecoder.get_field(
        rlp=rlp, field=TransactionField.R, rlp_start_offset=rlp_start_offset, tx_type=tx_type
    );

    return value;
}

func get_s_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let (tx_type, rlp_start_offset) = TransactionDecoder.open_tx_envelope(item=rlp);

    let value = TransactionDecoder.get_field(
        rlp=rlp, field=TransactionField.S, rlp_start_offset=rlp_start_offset, tx_type=tx_type
    );

    return value;
}

func get_chain_id_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let (tx_type, rlp_start_offset) = TransactionDecoder.open_tx_envelope(item=rlp);

    let value = TransactionDecoder.get_field(
        rlp=rlp, field=TransactionField.CHAIN_ID, rlp_start_offset=rlp_start_offset, tx_type=tx_type
    );

    return value;
}

func get_access_list_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let (tx_type, rlp_start_offset) = TransactionDecoder.open_tx_envelope(item=rlp);

    let value = TransactionDecoder.get_field(
        rlp=rlp,
        field=TransactionField.ACCESS_LIST,
        rlp_start_offset=rlp_start_offset,
        tx_type=tx_type,
    );

    return value;
}

func get_max_fee_per_gas_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let (tx_type, rlp_start_offset) = TransactionDecoder.open_tx_envelope(item=rlp);

    let value = TransactionDecoder.get_field(
        rlp=rlp,
        field=TransactionField.MAX_FEE_PER_GAS,
        rlp_start_offset=rlp_start_offset,
        tx_type=tx_type,
    );

    return value;
}

func get_max_priority_fee_per_gas_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let (tx_type, rlp_start_offset) = TransactionDecoder.open_tx_envelope(item=rlp);

    let value = TransactionDecoder.get_field(
        rlp=rlp,
        field=TransactionField.MAX_PRIORITY_FEE_PER_GAS,
        rlp_start_offset=rlp_start_offset,
        tx_type=tx_type,
    );

    return value;
}

func get_blob_versioned_hashes_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let (tx_type, rlp_start_offset) = TransactionDecoder.open_tx_envelope(item=rlp);

    let value = TransactionDecoder.get_field(
        rlp=rlp,
        field=TransactionField.BLOB_VERSIONED_HASHES,
        rlp_start_offset=rlp_start_offset,
        tx_type=tx_type,
    );

    return value;
}

func get_max_fee_per_blob_gas_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let (tx_type, rlp_start_offset) = TransactionDecoder.open_tx_envelope(item=rlp);

    let value = TransactionDecoder.get_field(
        rlp=rlp,
        field=TransactionField.MAX_FEE_PER_BLOB_GAS,
        rlp_start_offset=rlp_start_offset,
        tx_type=tx_type,
    );

    return value;
}

func get_tx_type_value{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, func_ptr: felt*, rlp: felt*
}() -> Uint256 {
    let (tx_type_felt, _rlp_start_offset) = TransactionDecoder.open_tx_envelope(item=rlp);

    let tx_type = Uint256(low=tx_type_felt, high=0);

    return tx_type;
}
