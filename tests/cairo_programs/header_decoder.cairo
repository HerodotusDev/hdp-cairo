%builtins range_check bitwise
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from src.decoders.header_decoder import HeaderDecoder, HEADER_FIELD
from packages.eth_essentials.lib.utils import pow2alloc128

func main{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}() {
    alloc_locals;
    let pow2_array: felt* = pow2alloc128();

    %{ print("Testing Homestead Block") %}
    test_header_decoding{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(block_number=150001);

    %{ print("Testing London Block (EIP-1559)") %}
    test_header_decoding{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(block_number=12965001);

    %{ print("Testing Shanghai Block") %}
    test_header_decoding{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(block_number=17034871);

    %{ print("Testing Dencun Block") %}
    test_header_decoding{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(block_number=19427930);

    return ();
}

func test_header_decoding{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    block_number: felt
) {
    alloc_locals;

    let (rlp) = alloc();
    local header_type: felt;
    local expected_parent_hash: Uint256;
    local expected_uncles_hash: Uint256;
    let (expected_coinbase) = alloc();
    local expected_state_root: Uint256;
    local expected_tx_root: Uint256;
    local expected_receipts_root: Uint256;
    let (expected_bloom_filter) = alloc();
    local expected_difficulty: Uint256;
    local expected_number: Uint256;
    local expected_gas_limit: Uint256;
    local expected_gas_used: Uint256;
    local expected_timestamp: Uint256;

    let (expected_extra_data) = alloc();
    local expected_extra_data_len: felt;
    local expected_extra_data_bytes_len: felt;
    local expected_mix_hash: Uint256;

    local expected_nonce: Uint256;
    local expected_base_fee_per_gas: Uint256;
    local expected_withdrawls_root: Uint256;

    local expected_blob_gas_used: Uint256;
    local expected_excess_blob_gas: Uint256;
    local expected_parent_beacon_root: Uint256;

    %{
        from tests.python.test_header_decoding import fetch_header_dict
        header = fetch_header_dict(ids.block_number)
        segments.write_arg(ids.rlp, header['rlp'])

        ids.expected_parent_hash.low = header['parent_hash']["low"]
        ids.expected_parent_hash.high = header['parent_hash']["high"]
        ids.expected_uncles_hash.low = header['uncles_hash']["low"]
        ids.expected_uncles_hash.high = header['uncles_hash']["high"]
        segments.write_arg(ids.expected_coinbase, header['coinbase'])
        ids.expected_state_root.low = header['state_root']["low"]
        ids.expected_state_root.high = header['state_root']["high"]
        ids.expected_tx_root.low = header['tx_root']["low"]
        ids.expected_tx_root.high = header['tx_root']["high"]
        ids.expected_receipts_root.low = header['receipts_root']["low"]
        ids.expected_receipts_root.high = header['receipts_root']["high"]
        segments.write_arg(ids.expected_bloom_filter, header['bloom'])
        ids.expected_difficulty.low = header['difficulty']
        ids.expected_number.low = header['number']
        ids.expected_number.high = 0
        ids.expected_gas_limit.low = header['gas_limit']
        ids.expected_gas_limit.high = 0
        ids.expected_gas_used.low = header['gas_used']
        ids.expected_gas_used.high = 0
        ids.expected_timestamp.low = header['timestamp']
        ids.expected_timestamp.high = 0
        segments.write_arg(ids.expected_extra_data, header['extra_data']['bytes'])
        ids.expected_extra_data_len = header['extra_data']['len']
        ids.expected_extra_data_bytes_len = header['extra_data']['bytes_len']

        ids.expected_mix_hash.low = header['mix_hash']["low"]
        ids.expected_mix_hash.high = header['mix_hash']["high"]

        ids.expected_nonce.low = header['nonce']
        ids.expected_nonce.high = 0
        ids.header_type = header["type"]

        if ids.header_type >=1 :
            ids.expected_base_fee_per_gas.low = header['base_fee_per_gas']

        if ids.header_type >= 2:
            ids.expected_withdrawls_root.low = header['withdrawls_root']["low"]
            ids.expected_withdrawls_root.high = header['withdrawls_root']["high"]

        if ids.header_type >= 3:
            ids.expected_blob_gas_used.low = header['blob_gas_used']
            ids.expected_excess_blob_gas.low = header['excess_blob_gas']
            ids.expected_parent_beacon_root.low = header['parent_beacon_block_root']["low"]
            ids.expected_parent_beacon_root.high = header['parent_beacon_block_root']["high"]
    %}

    let parent_hash = HeaderDecoder.get_field(rlp, HEADER_FIELD.PARENT);

    assert parent_hash.low = expected_parent_hash.low;
    assert parent_hash.high = expected_parent_hash.high;

    let uncles_hash = HeaderDecoder.get_field(rlp, HEADER_FIELD.UNCLE);
    assert uncles_hash.low = expected_uncles_hash.low;
    assert uncles_hash.high = expected_uncles_hash.high;

    let (coinbase, _, _) = HeaderDecoder.get_field_felt(rlp, HEADER_FIELD.COINBASE);
    assert coinbase[0] = expected_coinbase[0];
    assert coinbase[1] = expected_coinbase[1];
    assert coinbase[2] = expected_coinbase[2];

    let state_root = HeaderDecoder.get_field(rlp, HEADER_FIELD.STATE_ROOT);
    assert state_root.low = expected_state_root.low;
    assert state_root.high = expected_state_root.high;

    let tx_root = HeaderDecoder.get_field(rlp, HEADER_FIELD.TRANSACTION_ROOT);
    assert tx_root.low = expected_tx_root.low;
    assert tx_root.high = expected_tx_root.high;

    let receipts_root = HeaderDecoder.get_field(rlp, HEADER_FIELD.RECEIPT_ROOT);
    assert receipts_root.low = expected_receipts_root.low;
    assert receipts_root.high = expected_receipts_root.high;

    let (bloom_filter, value_len, bytes_len) = HeaderDecoder.get_field_felt(
        rlp, HEADER_FIELD.BLOOM
    );
    compare_bloom_filter(
        expected_bloom_filter=expected_bloom_filter,
        bloom_filter=bloom_filter,
        value_len=value_len,
        bytes_len=bytes_len,
    );

    let difficulty_le = HeaderDecoder.get_field(rlp, HEADER_FIELD.DIFFICULTY);
    let (local difficulty) = uint256_reverse_endian(difficulty_le);
    assert difficulty.low = expected_difficulty.low;
    assert difficulty.high = expected_difficulty.high;

    let number_le = HeaderDecoder.get_field(rlp, HEADER_FIELD.NUMBER);
    let (local number) = uint256_reverse_endian(number_le);

    assert number.low = expected_number.low;
    assert number.high = expected_number.high;

    let gas_limit_le = HeaderDecoder.get_field(rlp, HEADER_FIELD.GAS_LIMIT);
    let (local gas_limit) = uint256_reverse_endian(gas_limit_le);
    assert gas_limit.low = expected_gas_limit.low;
    assert gas_limit.high = expected_gas_limit.high;

    let gas_used_le = HeaderDecoder.get_field(rlp, HEADER_FIELD.GAS_USED);
    let (local gas_used) = uint256_reverse_endian(gas_used_le);
    assert gas_used.low = expected_gas_used.low;
    assert gas_used.high = expected_gas_used.high;

    let timestamp_le = HeaderDecoder.get_field(rlp, HEADER_FIELD.TIMESTAMP);
    let (local timestamp) = uint256_reverse_endian(timestamp_le);
    assert timestamp.low = expected_timestamp.low;
    assert timestamp.high = expected_timestamp.high;

    let (extra_data, extra_data_len, extra_data_bytes_len) = HeaderDecoder.get_field_felt(
        rlp, HEADER_FIELD.EXTRA_DATA
    );

    compare_extra_data(
        expected_extra_data=expected_extra_data,
        expected_extra_data_len=expected_extra_data_len,
        expected_extra_data_bytes_len=expected_extra_data_bytes_len,
        extra_data=extra_data,
        extra_data_len=extra_data_len,
        extra_data_bytes_len=extra_data_bytes_len,
    );

    let mix_hash = HeaderDecoder.get_field(rlp, HEADER_FIELD.MIX_HASH);
    assert mix_hash.low = expected_mix_hash.low;
    assert mix_hash.high = expected_mix_hash.high;

    let nonce_le = HeaderDecoder.get_field(rlp, HEADER_FIELD.NONCE);
    let (local nonce) = uint256_reverse_endian(nonce_le);
    assert nonce.low = expected_nonce.low;
    assert nonce.high = expected_nonce.high;

    local impl_london: felt;
    %{ ids.impl_london = 1 if ids.header_type >= 1 else 0 %}

    if (impl_london == 1) {
        let base_fee_per_gas_le = HeaderDecoder.get_field(rlp, HEADER_FIELD.BASE_FEE_PER_GAS);
        let (local base_fee_per_gas) = uint256_reverse_endian(base_fee_per_gas_le);
        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
        assert base_fee_per_gas.low = expected_base_fee_per_gas.low;
        assert base_fee_per_gas.high = expected_base_fee_per_gas.high;
    } else {
        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    }

    local impl_shanghai: felt;
    %{ ids.impl_shanghai = 1 if ids.header_type >= 2 else 0 %}
    if (impl_shanghai == 1) {
        let withdrawls_root = HeaderDecoder.get_field(rlp, HEADER_FIELD.WITHDRAWALS_ROOT);
        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
        assert withdrawls_root.low = expected_withdrawls_root.low;
        assert withdrawls_root.high = expected_withdrawls_root.high;
    } else {
        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    }

    local impl_dencun: felt;
    %{ ids.impl_dencun = 1 if ids.header_type >= 3 else 0 %}

    if (impl_dencun == 1) {
        let blob_gas_used_le = HeaderDecoder.get_field(rlp, HEADER_FIELD.BLOB_GAS_USED);
        let (local blob_gas_used) = uint256_reverse_endian(blob_gas_used_le);
        assert blob_gas_used.low = expected_blob_gas_used.low;
        assert blob_gas_used.high = expected_blob_gas_used.high;

        let excess_blob_gas_le = HeaderDecoder.get_field(rlp, HEADER_FIELD.EXCESS_BLOB_GAS);
        let (local excess_blob_gas) = uint256_reverse_endian(excess_blob_gas_le);
        assert excess_blob_gas.low = expected_excess_blob_gas.low;
        assert excess_blob_gas.high = expected_excess_blob_gas.high;

        let parent_beacon_root = HeaderDecoder.get_field(
            rlp, HEADER_FIELD.PARENT_BEACON_BLOCK_ROOT
        );
        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
        assert parent_beacon_root.low = expected_parent_beacon_root.low;
        assert parent_beacon_root.high = expected_parent_beacon_root.high;
    } else {
        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    }

    return ();
}

func compare_bloom_filter(
    expected_bloom_filter: felt*, bloom_filter: felt*, value_len: felt, bytes_len: felt
) {
    alloc_locals;

    assert value_len = 32;
    assert bytes_len = 256;

    tempvar i = 0;

    assert_loop:
    let i = [ap - 1];
    if (i == 32) {
        jmp end_loop;
    }

    assert expected_bloom_filter[i] = bloom_filter[i];
    [ap] = i + 1, ap++;
    jmp assert_loop;

    end_loop:
    return ();
}

func compare_extra_data(
    expected_extra_data: felt*,
    expected_extra_data_len: felt,
    expected_extra_data_bytes_len: felt,
    extra_data: felt*,
    extra_data_len: felt,
    extra_data_bytes_len: felt,
) {
    alloc_locals;

    assert expected_extra_data_len = extra_data_len;
    assert expected_extra_data_bytes_len = extra_data_bytes_len;

    tempvar i = 0;

    assert_loop:
    let i = [ap - 1];
    if (i == expected_extra_data_len) {
        jmp end_loop;
    }

    assert expected_extra_data[i] = extra_data[i];
    [ap] = i + 1, ap++;
    jmp assert_loop;

    end_loop:
    return ();
}
