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

    test_header_decoding{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array
    }(block_number=8150001);

    return ();
}

func test_header_decoding{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
}(block_number: felt) {
    alloc_locals;

    let (rlp) = alloc();

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

    return ();
}
