%builtins range_check bitwise keccak poseidon
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from src.hdp.decoders.header_decoder import HeaderDecoder
from src.libs.utils import pow2alloc128
from src.hdp.types import Transaction, ChainInfo
from src.hdp.decoders.transaction_decoder import (
    TransactionReader,
    TransactionSender,
    TransactionField,
)
from src.hdp.verifiers.transaction_verifier import init_tx_stuct
from src.hdp.chain_info import fetch_chain_info

func main{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;
    let pow2_array: felt* = pow2alloc128();
    let (local chain_info) = fetch_chain_info(1);

    local n_test_txs: felt;

    %{

        tx_array = [
            "0x2e923a6f09ba38f63ff9b722afd14b9e850432860b77df9011e92c1bf0eecf6b", # Type 0
            "0x237f99e622d67413956b8674cf16ea56b0ba0a18a9f68a5e254f4ac8d2050b51", # Type 1 (eip155)
            "0x423d6dfdeae9967847fb226e138ea5fad6279c12bf3343eae4d32c2477be3021", # Type 2
            "0x0d19225fe9ec3044d16008c3aceb0b9059cc22d66cd3ab847f6bd1e454342b4b", # Type 3
            "0x4b0070defa33cbc85f558323bf60132f600212cec3f4ab9e57260d40ff8949d9", # Type 4
            # Other edge cases that have failed before
            "0x15306e5f15afc5d178d705155bd38d70504795686f5f75f3d759ff3fb7fcb61d",
            "0x371882ee00ff668ca6bf9b1ec37fda5e1fa3a4d0b0f2fb4ef26611f1b1603d3e",
            "0xa10d0d5a82894137f33b85e8f40a028eb740acc3dd3b98ed85c16e8d5d57a803",
            "0xd675eaa76156b865c8d0aa1556dd08b0ed0bc2dc6531fc168f3d623aaa093230"
        ]

        #tx_array = ["0xd675eaa76156b865c8d0aa1556dd08b0ed0bc2dc6531fc168f3d623aaa093230"]

        ids.n_test_txs = len(tx_array)
    %}

    // run default tests first
    test_tx_decoding_inner{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
        keccak_ptr=keccak_ptr,
        poseidon_ptr=poseidon_ptr,
        chain_info=chain_info,
    }(n_test_txs, 0);

    // test_tx_decoding{
    //     range_check_ptr=range_check_ptr,
    //     bitwise_ptr=bitwise_ptr,
    //     pow2_array=pow2_array,
    //     keccak_ptr=keccak_ptr,
    //     poseidon_ptr=poseidon_ptr,
    //     chain_info=chain_info,
    // }(0);

    return ();
}

func test_tx_decoding{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    chain_info: ChainInfo,
}(index: felt) {
    alloc_locals;
    local n_test_txs: felt;

    %{
        from tests.python.test_tx_decoding import fetch_block_tx_ids, fetch_latest_block_height
        import random
        random.seed(ids.index)
        block_sample = 10
        latest_height = fetch_latest_block_height()
        selected_block = random.randrange(1, latest_height)
        print("Selected Block:", selected_block)
        tx_array = fetch_block_tx_ids(selected_block)

        if(len(tx_array) >= block_sample):
            tx_array = random.sample(tx_array, 10)
            
        ids.n_test_txs = len(tx_array)
    %}

     // run default tests first
    test_tx_decoding_inner{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
        keccak_ptr=keccak_ptr,
        poseidon_ptr=poseidon_ptr,
        chain_info=chain_info,
    }(n_test_txs, 0);

    return test_tx_decoding(index + 1);
}

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

    let nonce = TransactionReader.get_field(tx, TransactionField.NONCE);
    assert expected_nonce.low = nonce.low;
    assert expected_nonce.high = nonce.high;

    let gas_limit = TransactionReader.get_field(tx, TransactionField.GAS_LIMIT);
    assert expected_gas_limit.low = gas_limit.low;
    assert expected_gas_limit.high = gas_limit.high;

    let (receiver, receiver_len, _) = TransactionReader.get_felt_field(tx, TransactionField.RECEIVER);
    assert expected_receiver[0] = receiver[0];

    // prevent failing checks for contract creation transactions
    if(receiver_len == 3) {
        assert expected_receiver[1] = receiver[1];
        assert expected_receiver[2] = receiver[2];
    }
    let value = TransactionReader.get_field(tx, TransactionField.VALUE);
    assert expected_value.low = value.low;
    assert expected_value.high = value.high;

    eval_felt_field{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(expected_input, expected_input_len, expected_input_bytes_len, tx, TransactionField.INPUT);

    let v = TransactionReader.get_field(tx, TransactionField.V);
    assert expected_v.low = v.low;
    assert expected_v.high = v.high;

    let r = TransactionReader.get_field(tx, TransactionField.R);
    assert expected_r.low = r.low;
    assert expected_r.high = r.high;

    let s = TransactionReader.get_field(tx, TransactionField.S);

    // %{
    //     print("Rec S: ", hex(ids.s.high) + hex(ids.s.low)[2:])
    //     print("Exp S: ", hex(ids.expected_s.high) + hex(ids.expected_s.low)[2:])
    //     # print("Exp S: ", hex(ids.expected_s.low), hex(ids.expected_s.high))
    // %}
    assert expected_s.low = s.low;
    assert expected_s.high = s.high;

    local has_legacy: felt;
    %{ ids.has_legacy = 1 if ids.tx.type <= 1 else 0 %}
    if (has_legacy == 1) {
        let gas_price = TransactionReader.get_field(tx, TransactionField.GAS_PRICE);
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
        let max_prio_fee_per_gas = TransactionReader.get_field(
            tx, TransactionField.MAX_PRIORITY_FEE_PER_GAS
        );
        assert expected_max_prio_fee_per_gas.low = max_prio_fee_per_gas.low;
        assert expected_max_prio_fee_per_gas.high = max_prio_fee_per_gas.high;

        let max_fee_per_gas = TransactionReader.get_field(
            tx, TransactionField.MAX_FEE_PER_GAS
        );
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

        let max_fee_per_blob_gas = TransactionReader.get_field(
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

    let (res, res_len, res_bytes_len) = TransactionReader.get_felt_field(tx, field);

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
