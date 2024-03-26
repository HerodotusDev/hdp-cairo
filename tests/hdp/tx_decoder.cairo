%builtins range_check bitwise
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from src.hdp.decoders.header_decoder import HeaderDecoder
from src.libs.utils import pow2alloc128
from src.hdp.types import Transaction
from src.hdp.decoders.transaction_decoder import TransactionReader

func main{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let pow2_array: felt* = pow2alloc128();

    %{ print("Testing Type 2") %}
    test_type_2{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array
    }();

    return ();
}

func test_type_2{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
}() {
    alloc_locals;

    let (rlp) = alloc();
    local rlp_len = 15;
    local bytes_len = 114;

    local expected_chain_id: Uint256;
    local expected_nonce: Uint256;
    local expected_max_prio_fee: Uint256;
    local expected_max_fee: Uint256;
    local expected_gas_limit: Uint256;
    local expected_value: Uint256;

    local expected_v: Uint256;
    local expected_r: Uint256;
    local expected_s: Uint256;

    let (expected_receiver) = alloc();
    let (expected_input) = alloc();
    let (expected_access_list) = alloc();



    %{ 
        from tools.py.utils import (
            bytes_to_8_bytes_chunks_little,
        )

        rlp_chunks = [0x8562123202840501, 0x852825f7124d70f, 0x7bfdc2663ad00794, 0x43ca7711aeb4609e, 0x862387bb8478969d, 0x80c0800000c16ff2, 0x7c1fd3583c5bbca0, 0x1dd9c245a8f06926, 0x75f73fe1a5954ec, 0x339a6dcb69ef2344, 0x722687a3075ba087, 0x3260cc35db3fc512, 0x27bd707a26e541a, 0x4f76c8d336d82783, 0xbe6e]
        segments.write_arg(ids.rlp, rlp_chunks)

        receiver = bytes_to_8_bytes_chunks_little(bytes.fromhex("07d03A66c2fd7B9E60B4ae1177Ca439d967884bB"))
        segments.write_arg(ids.expected_receiver, receiver)

        segments.write_arg(ids.expected_input, [0])
        segments.write_arg(ids.expected_access_list, [0])

        ids.expected_chain_id.low = 1
        ids.expected_chain_id.high = 0

        ids.expected_nonce.low = 5
        ids.expected_nonce.high = 0

        ids.expected_max_prio_fee.low = 36835938
        ids.expected_max_prio_fee.high = 0

        ids.expected_max_fee.low = 68033999199
        ids.expected_max_fee.high = 0

        ids.expected_gas_limit.low = 21000
        ids.expected_gas_limit.high = 0

        ids.expected_value.low = 10000000000000000
        ids.expected_value.high = 0

        ids.expected_v.low = 0
        ids.expected_v.high = 0

        ids.expected_r.low = 0x54591afe735f074423ef69cb6d9a3387
        ids.expected_r.high = 0xbc5b3c58d31f7c2669f0a845c2d91dec

        ids.expected_s.low = 0x6ea207d77b028327d836d3c8764f6ebe
        ids.expected_s.high = 0x5b07a387267212c53fdb35cc60321a54




    %}

    let tx = Transaction(
        rlp=rlp,
        rlp_len=rlp_len,
        bytes_len=bytes_len,
        type=2
    );

    let nonce = TransactionReader.get_field_by_index(tx, 0);
    assert expected_nonce.low = nonce.low;
    assert expected_nonce.high = nonce.high;

    // N/A: Field 1

    let gas_limit = TransactionReader.get_field_by_index(tx, 2);
    assert expected_gas_limit.low = gas_limit.low;
    assert expected_gas_limit.high = gas_limit.high;

    let (receiver, _, _) = TransactionReader.get_felt_field_by_index(tx, 3);
    assert expected_receiver[0] = receiver[0];
    assert expected_receiver[1] = receiver[1];
    assert expected_receiver[2] = receiver[2];

    let value = TransactionReader.get_field_by_index(tx, 4);
    assert expected_value.low = value.low;
    assert expected_value.high = value.high;

    let (input, input_len, bytes_len) = TransactionReader.get_felt_field_by_index(tx, 5);
    assert expected_input[0] = input[0];
    assert input_len = 1;
    assert bytes_len = 1;

    let v = TransactionReader.get_field_by_index(tx, 6);
    assert expected_v.low = v.low;
    assert expected_v.high = v.high;

    let r = TransactionReader.get_field_by_index(tx, 7);
    assert expected_r.low = r.low;
    assert expected_r.high = r.high;

    let s = TransactionReader.get_field_by_index(tx, 8);
    assert expected_s.low = s.low;
    assert expected_s.high = s.high;

    let chain_id = TransactionReader.get_field_by_index(tx, 9);
    assert expected_chain_id.low = chain_id.low;
    assert expected_chain_id.high = chain_id.high;

    let (access_list, access_list_len, bytes_len) = TransactionReader.get_felt_field_by_index(tx, 10);
    assert expected_access_list[0] = access_list[0];
    assert access_list_len = 1;
    assert bytes_len = 1;

    let max_fee = TransactionReader.get_field_by_index(tx, 11);
    assert expected_max_fee.low = max_fee.low;
    assert expected_max_fee.high = max_fee.high;

    let max_prio_fee = TransactionReader.get_field_by_index(tx, 12);
    assert expected_max_prio_fee.low = max_prio_fee.low;
    assert expected_max_prio_fee.high = max_prio_fee.high;

    return ();

}