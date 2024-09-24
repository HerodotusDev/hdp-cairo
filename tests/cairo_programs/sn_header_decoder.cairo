%builtins range_check
from src.decoders.starknet.header_decoder import get_header_field_index, StarknetHeaderVersion, StarknetHeaderFields

func main{
    range_check_ptr
}() {
    let version = StarknetHeaderVersion.VERSION_1;

    let index = get_header_field_index(version, StarknetHeaderFields.BLOCK_NUMBER);
    assert index = 0;
    let index = get_header_field_index(version, StarknetHeaderFields.GLOBAL_STATE_ROOT);
    assert index = 1;

    let index = get_header_field_index(version, StarknetHeaderFields.SEQUENCER_ADDRESS);
    assert index = 2;

    let index = get_header_field_index(version, StarknetHeaderFields.BLOCK_TIMESTAMP);
    assert index = 3;

    let index = get_header_field_index(version, StarknetHeaderFields.TRANSACTION_COUNT);
    assert index = 4;

    let index = get_header_field_index(version, StarknetHeaderFields.TRANSACTION_COMMITMENT);
    assert index = 5;

    let index = get_header_field_index(version, StarknetHeaderFields.EVENT_COUNT);
    assert index = 6;

    let index = get_header_field_index(version, StarknetHeaderFields.EVENT_COMMITMENT);
    assert index = 7;

    let index = get_header_field_index(version, StarknetHeaderFields.PARENT_BLOCK_HASH);
    assert index = 10;

    let version = StarknetHeaderVersion.VERSION_2;

    let index = get_header_field_index(version, StarknetHeaderFields.BLOCK_NUMBER);
    assert index = 1;

    let index = get_header_field_index(version, StarknetHeaderFields.GLOBAL_STATE_ROOT);
    assert index = 2;

    let index = get_header_field_index(version, StarknetHeaderFields.SEQUENCER_ADDRESS);
    assert index = 3;

    let index = get_header_field_index(version, StarknetHeaderFields.BLOCK_TIMESTAMP);
    assert index = 4;

    let index = get_header_field_index(version, StarknetHeaderFields.TRANSACTION_COUNT);
    assert index = 5;

    let index = get_header_field_index(version, StarknetHeaderFields.TRANSACTION_COMMITMENT);
    assert index = 7;

    let index = get_header_field_index(version, StarknetHeaderFields.EVENT_COUNT);
    assert index = 5;

    let index = get_header_field_index(version, StarknetHeaderFields.EVENT_COMMITMENT);
    assert index = 8;

    let index = get_header_field_index(version, StarknetHeaderFields.PARENT_BLOCK_HASH);
    assert index = 15;

    let index = get_header_field_index(version, StarknetHeaderFields.STATE_DIFF_COMMITMENT);
    assert index = 6;

    let index = get_header_field_index(version, StarknetHeaderFields.STATE_DIFF_LENGTH);
    assert index = 5;

    let index = get_header_field_index(version, StarknetHeaderFields.L1_GAS_PRICE_IN_WEI);
    assert index = 9;

    let index = get_header_field_index(version, StarknetHeaderFields.L1_GAS_PRICE_IN_FRI);
    assert index = 10;

    let index = get_header_field_index(version, StarknetHeaderFields.L1_DATA_GAS_PRICE_IN_WEI);
    assert index = 11;

    let index = get_header_field_index(version, StarknetHeaderFields.L1_DATA_GAS_PRICE_IN_FRI);
    assert index = 12;

    let index = get_header_field_index(version, StarknetHeaderFields.RECEIPTS_COMMITMENT);
    assert index = 13;

    let index = get_header_field_index(version, StarknetHeaderFields.L1_DATA_MODE);
    assert index = 5;

    return ();
}