%builtins range_check bitwise
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from src.hdp.header_decoding import HeaderReader
from src.libs.utils import pow2alloc128

func main{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let pow2_array: felt* = pow2alloc128();

    %{ print("Testing Homestead Block") %}
    test_header_decoding{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array
    }(block_number=150001);

    %{ print("Testing London Block (EIP-1559)") %}
    test_header_decoding{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array
    }(block_number=12965001);
   
    %{ print("Testing Shanghai Block") %}
    test_header_decoding{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array
    }(block_number=17034871);

    // Sepolia tests
    // %{ print("Testing Pre-Dencun Block") %}
    // test_header_decoding{
    //     range_check_ptr=range_check_ptr,
    //     bitwise_ptr=bitwise_ptr,
    //     pow2_array=pow2_array
    // }(block_number=5187022);

    // %{ print("Testing Dencun Block") %}
    // test_header_decoding{
    //     range_check_ptr=range_check_ptr,
    //     bitwise_ptr=bitwise_ptr,
    //     pow2_array=pow2_array
    // }(block_number=5476434);

    return ();
}

func test_header_decoding{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
}(block_number: felt) {
    alloc_locals;

    let (rlp) = alloc();
    local header_type: felt;
    local expected_parent_hash: Uint256;
    local expected_uncles_hash: Uint256;
    let (expected_coinbase) = alloc();
    local expected_state_root: Uint256;
    local expected_tx_root: Uint256;
    local expected_receipts_root: Uint256;
    local expected_difficulty: Uint256;
    local expected_number: Uint256;
    local expected_gas_limit: Uint256;
    local expected_gas_used: Uint256;
    local expected_timestamp: Uint256;
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
        ids.expected_difficulty.low = header['difficulty']
        ids.expected_number.low = header['number']
        ids.expected_gas_limit.low = header['gas_limit']
        ids.expected_gas_used.low = header['gas_used']
        ids.expected_timestamp.low = header['timestamp']
        ids.expected_nonce.low = header['nonce']
        ids.header_type = header["type"]

        if ids.header_type >=1 :
            ids.expected_base_fee_per_gas.low = header['base_fee_per_gas']
        elif ids.header_type >= 2:
            ids.expected_withdrawls_root.low = header['withdrawls_root']["low"]
            ids.expected_withdrawls_root.high = header['withdrawls_root']["high"]
        elif ids.header_type >= 3:
            ids.expected_blob_gas_used.low = header['blob_gas_used']
            ids.expected_excess_blob_gas.low = header['excess_blob_gas']
            ids.expected_parent_beacon_root.low = header['parent_beacon_block_root']["low"]
            ids.expected_parent_beacon_root.high = header['parent_beacon_block_root']["high"]
    %}

    let parent_hash = HeaderReader.get_field(rlp, 0);

    assert parent_hash.low = expected_parent_hash.low;
    assert parent_hash.high = expected_parent_hash.high;

    let uncles_hash = HeaderReader.get_field(rlp, 1);
    assert uncles_hash.low = expected_uncles_hash.low;
    assert uncles_hash.high = expected_uncles_hash.high;

    let coinbase = HeaderReader.get_coinbase(rlp);
    assert coinbase[0] = expected_coinbase[0];
    assert coinbase[1] = expected_coinbase[1];
    assert coinbase[2] = expected_coinbase[2];

    let state_root = HeaderReader.get_field(rlp, 3);
    assert state_root.low = expected_state_root.low;
    assert state_root.high = expected_state_root.high;

    let tx_root = HeaderReader.get_field(rlp, 4);
    assert tx_root.low = expected_tx_root.low;
    assert tx_root.high = expected_tx_root.high;

    let receipts_root = HeaderReader.get_field(rlp, 5);
    assert receipts_root.low = expected_receipts_root.low;
    assert receipts_root.high = expected_receipts_root.high;

    // missing logsBloom

    let difficulty = HeaderReader.get_field(rlp, 7);
    assert difficulty.low = expected_difficulty.low;
    assert difficulty.high = expected_difficulty.high;

    let number = HeaderReader.get_field(rlp, 8);
    assert number.low = expected_number.low;
    assert number.high = expected_number.high;

    let gas_limit = HeaderReader.get_field(rlp, 9);
    assert gas_limit.low = expected_gas_limit.low;
    assert gas_limit.high = expected_gas_limit.high;

    let gas_used = HeaderReader.get_field(rlp, 10);
    assert gas_used.low = expected_gas_used.low;
    assert gas_used.high = expected_gas_used.high;

    let timestamp = HeaderReader.get_field(rlp, 11);
    assert timestamp.low = expected_timestamp.low;
    assert timestamp.high = expected_timestamp.high;

    // missing extraData + mixHash

    let nonce = HeaderReader.get_field(rlp, 14);
    assert nonce.low = expected_nonce.low;
    assert nonce.high = expected_nonce.high;

    local impl_london: felt;
    %{ ids.impl_london = 1 if ids.header_type >= 1 else 0 %}

    if(impl_london == 1){
        let base_fee_per_gas = HeaderReader.get_field(rlp, 15);
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
    if(impl_shanghai == 1){
        let withdrawls_root = HeaderReader.get_field(rlp, 16);
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
    if(impl_dencun == 1){
        let blob_gas_used = HeaderReader.get_field(rlp, 17);
        assert blob_gas_used.low = expected_blob_gas_used.low;
        assert blob_gas_used.high = expected_blob_gas_used.high;

        let excess_blob_gas = HeaderReader.get_field(rlp, 18);
        assert excess_blob_gas.low = expected_excess_blob_gas.low;
        assert excess_blob_gas.high = expected_excess_blob_gas.high;

        let parent_beacon_root = HeaderReader.get_field(rlp, 19);
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