from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin

from src.types import Transaction, ChainInfo
from src.decoders.transaction_decoder import TransactionDecoder, TransactionSender, TransactionField
from src.verifiers.transaction_verifier import init_tx_stuct

func test_tx_decoding_inner{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    chain_info: ChainInfo,
}(txs: felt, index: felt) {
    alloc_locals;

    if (txs == index) {
        return ();
    }

    let (rlp) = alloc();
    local rlp_len: felt;
    local rlp_bytes_len: felt;
    local block_number: felt;

    local expected_nonce: Uint256;
    local expected_gas_limit: Uint256;
    let (expected_receiver) = alloc();
    local expected_value: Uint256;
    local expected_v: Uint256;
    local expected_r: Uint256;
    local expected_s: Uint256;

    let (expected_input) = alloc();
    local expected_input_len: felt;
    local expected_input_bytes_len: felt;

    local expected_gas_price: Uint256;
    local expected_max_prio_fee_per_gas: Uint256;
    local expected_max_fee_per_gas: Uint256;

    let (expected_access_list) = alloc();
    local expected_access_list_len: felt;
    local expected_access_list_bytes_len: felt;

    local expected_max_fee_per_blob_gas: Uint256;
    let (expected_blob_versioned_hashes) = alloc();
    local expected_blob_versioned_hashes_len: felt;
    local expected_blob_versioned_hashes_bytes_len: felt;

    local expected_sender: felt;

    %{
        from tools.py.utils import (
            bytes_to_8_bytes_chunks_little,
        )
        from tests.python.test_tx_decoding import fetch_transaction_dict
        print("Running TX:", tx_array[ids.index])
        tx_dict = fetch_transaction_dict(tx_array[ids.index])

        ids.block_number = tx_dict["block_number"]

        segments.write_arg(ids.rlp, tx_dict["rlp"])
        ids.rlp_len = len(tx_dict["rlp"])
        ids.rlp_bytes_len = tx_dict["rlp_bytes_len"]

        ids.expected_nonce.low = tx_dict["nonce"]["low"]
        ids.expected_nonce.high = tx_dict["nonce"]["high"]

        ids.expected_gas_limit.low = tx_dict["gas_limit"]["low"]
        ids.expected_gas_limit.high = tx_dict["gas_limit"]["high"]

        segments.write_arg(ids.expected_receiver, tx_dict["receiver"])

        ids.expected_value.low = tx_dict["value"]["low"]
        ids.expected_value.high = tx_dict["value"]["high"]

        segments.write_arg(ids.expected_input, tx_dict["input"]["chunks"])
        ids.expected_input_len = len(tx_dict["input"]["chunks"])
        ids.expected_input_bytes_len = tx_dict["input"]["bytes_len"]

        ids.expected_v.low = tx_dict["v"]["low"]
        ids.expected_v.high = tx_dict["v"]["high"]

        ids.expected_r.low = tx_dict["r"]["low"]
        ids.expected_r.high = tx_dict["r"]["high"]

        ids.expected_s.low = tx_dict["s"]["low"]
        ids.expected_s.high = tx_dict["s"]["high"]

        ids.expected_sender = tx_dict["sender"]

        if tx_dict["type"] <= 1:
            ids.expected_gas_price.low = tx_dict["gas_price"]["low"]
            ids.expected_gas_price.high = tx_dict["gas_price"]["high"]
        else:
            ids.expected_max_prio_fee_per_gas.low = tx_dict["max_priority_fee_per_gas"]["low"]
            ids.expected_max_prio_fee_per_gas.high = tx_dict["max_priority_fee_per_gas"]["high"]

            ids.expected_max_fee_per_gas.low = tx_dict["max_fee_per_gas"]["low"]
            ids.expected_max_fee_per_gas.high = tx_dict["max_fee_per_gas"]["high"]

        if tx_dict["type"] >= 1:
            segments.write_arg(ids.expected_access_list, tx_dict["access_list"]["chunks"])
            ids.expected_access_list_len = len(tx_dict["access_list"]["chunks"])
            ids.expected_access_list_bytes_len = tx_dict["access_list"]["bytes_len"]

        if tx_dict["type"] == 3:
            segments.write_arg(ids.expected_blob_versioned_hashes, tx_dict["blob_versioned_hashes"]["chunks"])
            ids.expected_blob_versioned_hashes_len = len(tx_dict["blob_versioned_hashes"]["chunks"])
            ids.expected_blob_versioned_hashes_bytes_len = tx_dict["blob_versioned_hashes"]["bytes_len"]

            ids.expected_max_fee_per_blob_gas.low = tx_dict["max_fee_per_blob_gas"]["low"]
            ids.expected_max_fee_per_blob_gas.high = tx_dict["max_fee_per_blob_gas"]["high"]
    %}

    let tx = init_tx_stuct(rlp, rlp_bytes_len, block_number);

    let nonce = TransactionDecoder.get_field(tx, TransactionField.NONCE);
    assert expected_nonce.low = nonce.low;
    assert expected_nonce.high = nonce.high;

    let gas_limit = TransactionDecoder.get_field(tx, TransactionField.GAS_LIMIT);
    assert expected_gas_limit.low = gas_limit.low;
    assert expected_gas_limit.high = gas_limit.high;

    let (receiver, receiver_len, _) = TransactionDecoder.get_felt_field(
        tx, TransactionField.RECEIVER
    );
    assert expected_receiver[0] = receiver[0];

    // prevent failing checks for contract creation transactions
    if (receiver_len == 3) {
        assert expected_receiver[1] = receiver[1];
        assert expected_receiver[2] = receiver[2];
    }
    let value = TransactionDecoder.get_field(tx, TransactionField.VALUE);
    assert expected_value.low = value.low;
    assert expected_value.high = value.high;

    eval_felt_field{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(expected_input, expected_input_len, expected_input_bytes_len, tx, TransactionField.INPUT);

    let v = TransactionDecoder.get_field(tx, TransactionField.V);
    assert expected_v.low = v.low;
    assert expected_v.high = v.high;

    let r = TransactionDecoder.get_field(tx, TransactionField.R);
    assert expected_r.low = r.low;
    assert expected_r.high = r.high;

    let s = TransactionDecoder.get_field(tx, TransactionField.S);
    assert expected_s.low = s.low;
    assert expected_s.high = s.high;

    local has_legacy: felt;
    %{ ids.has_legacy = 1 if ids.tx.type <= 1 else 0 %}
    if (has_legacy == 1) {
        let gas_price = TransactionDecoder.get_field(tx, TransactionField.GAS_PRICE);
        assert expected_gas_price.low = gas_price.low;
        assert expected_gas_price.high = gas_price.high;

        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    } else {
        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    }

    local has_eip2930: felt;
    %{ ids.has_eip2930 = 1 if ids.tx.type >= 2 else 0 %}
    if (has_eip2930 == 1) {
        eval_felt_field{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
        }(
            expected_access_list,
            expected_access_list_len,
            expected_access_list_bytes_len,
            tx,
            TransactionField.ACCESS_LIST,
        );

        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    } else {
        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    }

    local has_eip1559: felt;
    %{ ids.has_eip1559 = 1 if ids.tx.type >= 3 else 0 %}
    if (has_eip1559 == 1) {
        let max_prio_fee_per_gas = TransactionDecoder.get_field(
            tx, TransactionField.MAX_PRIORITY_FEE_PER_GAS
        );
        assert expected_max_prio_fee_per_gas.low = max_prio_fee_per_gas.low;
        assert expected_max_prio_fee_per_gas.high = max_prio_fee_per_gas.high;

        let max_fee_per_gas = TransactionDecoder.get_field(tx, TransactionField.MAX_FEE_PER_GAS);
        assert max_fee_per_gas.low = expected_max_fee_per_gas.low;
        assert max_fee_per_gas.high = expected_max_fee_per_gas.high;

        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    } else {
        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    }

    local has_blob_versioned_hashes: felt;
    %{ ids.has_blob_versioned_hashes = 1 if ids.tx.type == 4 else 0 %}
    if (has_blob_versioned_hashes == 1) {
        eval_felt_field{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
        }(
            expected_blob_versioned_hashes,
            expected_blob_versioned_hashes_len,
            expected_blob_versioned_hashes_bytes_len,
            tx,
            TransactionField.BLOB_VERSIONED_HASHES,
        );

        let max_fee_per_blob_gas = TransactionDecoder.get_field(
            tx, TransactionField.MAX_FEE_PER_BLOB_GAS
        );
        assert max_fee_per_blob_gas.low = expected_max_fee_per_blob_gas.low;
        assert max_fee_per_blob_gas.high = expected_max_fee_per_blob_gas.high;

        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    } else {
        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    }

    let sender = TransactionSender.derive(tx);
    assert sender = expected_sender;

    return test_tx_decoding_inner(txs, index + 1);
}

func eval_felt_field{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    expected: felt*, expected_len: felt, expected_bytes_len: felt, tx: Transaction, field: felt
) {
    alloc_locals;

    let (res, res_len, res_bytes_len) = TransactionDecoder.get_felt_field(tx, field);

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
