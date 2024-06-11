from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin

from src.types import Receipt, ChainInfo
from src.decoders.receipt_decoder import ReceiptDecoder, ReceiptField
from src.verifiers.receipt_verifier import derive_receipt_payload

func test_receipt_decoding_inner{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    chain_info: ChainInfo,
}(receipts: felt, index: felt) {
    alloc_locals;

    if (receipts == index) {
        return ();
    }

    let (rlp) = alloc();
    local rlp_len: felt;
    local rlp_bytes_len: felt;

    local expected_success: Uint256;
    local expected_cumulative_gas_used: Uint256;
    local expected_type: felt;
    local block_number: felt;

    let (expected_bloom) = alloc();
    local expected_bloom_len: felt;
    local expected_bloom_bytes_len: felt;

    let (expected_logs) = alloc();
    local expected_logs_len: felt;
    local expected_logs_bytes_len: felt;

    local block_number: felt;
    %{
        from tools.py.utils import (
            bytes_to_8_bytes_chunks_little,
        )
        from tests.python.test_receipt_decoding import fetch_receipt_dict
        print("Running TX:", receipt_array[ids.index])
        receipt_dict = fetch_receipt_dict(receipt_array[ids.index])

        segments.write_arg(ids.rlp, receipt_dict["rlp"])
        ids.rlp_len = len(receipt_dict["rlp"])
        ids.rlp_bytes_len = receipt_dict["rlp_bytes_len"]

        ids.expected_success.low = receipt_dict["success"]["low"]
        ids.expected_success.high = receipt_dict["success"]["high"]

        ids.expected_cumulative_gas_used.low = receipt_dict["cumulative_gas_used"]["low"]
        ids.expected_cumulative_gas_used.high = receipt_dict["cumulative_gas_used"]["high"]

        segments.write_arg(ids.expected_bloom, receipt_dict["bloom"]["chunks"])
        ids.expected_bloom_len = len(receipt_dict["bloom"]["chunks"])
        ids.expected_bloom_bytes_len = receipt_dict["bloom"]["bytes_len"]

        segments.write_arg(ids.expected_logs, receipt_dict["logs"]["chunks"])
        ids.expected_logs_len = len(receipt_dict["logs"]["chunks"])
        ids.expected_logs_bytes_len = receipt_dict["logs"]["bytes_len"]

        ids.block_number = receipt_dict["block_number"]
        ids.expected_type = receipt_dict["type"]
    %}

    let (rlp, rlp_len, bytes_len, receipt_type) = derive_receipt_payload(
        item=rlp, item_bytes_len=rlp_bytes_len
    );

    assert receipt_type = expected_type;

    let receipt = Receipt(
        rlp=rlp, rlp_len=rlp_len, bytes_len=bytes_len, type=receipt_type, block_number=block_number
    );

    let success = ReceiptDecoder.get_field(receipt, ReceiptField.SUCCESS);
    assert success.low = expected_success.low;
    assert success.high = expected_success.high;

    let cumulative_gas_used = ReceiptDecoder.get_field(receipt, ReceiptField.CUMULATIVE_GAS_USED);
    assert cumulative_gas_used.low = expected_cumulative_gas_used.low;
    assert cumulative_gas_used.high = expected_cumulative_gas_used.high;

    eval_felt_field{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(expected_bloom, expected_bloom_len, expected_bloom_bytes_len, receipt, ReceiptField.BLOOM);

    eval_felt_field{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(expected_logs, expected_logs_len, expected_logs_bytes_len, receipt, ReceiptField.LOGS);

    return test_receipt_decoding_inner(receipts, index + 1);
}

func eval_felt_field{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, chain_info: ChainInfo
}(expected: felt*, expected_len: felt, expected_bytes_len: felt, receipt: Receipt, field: felt) {
    alloc_locals;

    let (res, res_len, res_bytes_len) = ReceiptDecoder.get_felt_field(receipt, field);

    %{
        i = 0
        while(i < ids.res_len):
            #print("Expected:", hex(memory[ids.expected + i]), "Got:",hex(memory[ids.res + i]))
            assert memory[ids.res + i] == memory[ids.expected + i], f"Value Missmatch for field: {ids.field} at index: {i}"
            i += 1
    %}

    assert expected_len = res_len;
    assert expected_bytes_len = res_bytes_len;

    return ();
}
