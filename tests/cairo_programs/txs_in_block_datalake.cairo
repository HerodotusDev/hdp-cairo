%builtins range_check bitwise keccak
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.alloc import alloc

from packages.eth_essentials.lib.utils import pow2alloc128
from src.datalakes.txs_in_block_datalake import init_txs_in_block

func main{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}() {
    alloc_locals;
    let pow2_array: felt* = pow2alloc128();

    let (input: felt*) = alloc();
    local input_bytes_len: felt;

    %{
        encoded_datalakes = [
            "00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000AA36A700000000000000000000000000000000000000000000000000000000005595f50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005c0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000101000000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000020100000000000000000000000000000000000000000000000000000000000000",
            "00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000AA36A700000000000000000000000000000000000000000000000000000000005595f50000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000005c0000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000020104000000000000000000000000000000000000000000000000000000000000",
            "00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000AA36A700000000000000000000000000000000000000000000000000000000005595f50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005a000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000101010100000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000020104000000000000000000000000000000000000000000000000000000000000"
        ]

        expected_datalakes = [
            {
                "chain_id": 11155111,
                "target_block": 5608949,
                "start_index": 0,
                "end_index": 92,
                "increment": 1,
                "included_types": [1, 1, 0, 0],
                "sampled_property": 0,
                "type": 1,

            },
            {
                "chain_id": 11155111,
                "target_block": 5608949,
                "start_index": 5,
                "end_index": 92,
                "increment": 3,
                "included_types":[0,0,1,1],
                "sampled_property": 4,
                "type": 1,
            },
            {
                "chain_id": 11155111,
                "target_block": 5608949,
                "start_index": 0,
                "end_index": 90,
                "increment": 10,
                "included_types":[1,1,1,1],
                "sampled_property": 4,
                "type": 1,
            }
        ]
    %}

    eval{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        pow2_array=pow2_array,
    }(count=3, index=0);

    return ();
}

func eval{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*, pow2_array: felt*
}(count: felt, index: felt) {
    alloc_locals;
    if (count == index) {
        return ();
    }

    let (input_chunks) = alloc();
    local chain_id: felt;
    local input_bytes_len: felt;
    local target_block: felt;
    local start_index: felt;
    local end_index: felt;
    local increment: felt;
    local sampled_property: felt;
    local type: felt;

    %{
        from tools.py.utils import (
            bytes_to_8_bytes_chunks_little,
        )

        input_bytes = bytes.fromhex(encoded_datalakes[ids.index])
        ids.input_bytes_len = len(input_bytes)

        input_chunks = bytes_to_8_bytes_chunks_little(input_bytes)
        segments.write_arg(ids.input_chunks, input_chunks)
        ids.chain_id = expected_datalakes[ids.index]["chain_id"]
        ids.target_block = expected_datalakes[ids.index]["target_block"]
        ids.start_index = expected_datalakes[ids.index]["start_index"]
        ids.end_index = expected_datalakes[ids.index]["end_index"]
        ids.increment = expected_datalakes[ids.index]["increment"]
        ids.type = expected_datalakes[ids.index]["type"]
        ids.sampled_property = expected_datalakes[ids.index]["sampled_property"]
    %}

    let (result) = init_txs_in_block{pow2_array=pow2_array}(
        input=input_chunks, input_bytes_len=input_bytes_len
    );

    assert result.chain_id = chain_id;
    assert result.target_block = target_block;
    assert result.start_index = start_index;
    assert result.end_index = end_index;
    assert result.increment = increment;
    assert result.type = type;
    assert result.sampled_property = sampled_property;

    %{
        assert memory[ids.result.included_types] == expected_datalakes[ids.index]["included_types"][0]
        assert memory[ids.result.included_types + 1] == expected_datalakes[ids.index]["included_types"][1]
        assert memory[ids.result.included_types + 2] == expected_datalakes[ids.index]["included_types"][2]
        assert memory[ids.result.included_types + 3] == expected_datalakes[ids.index]["included_types"][3]
    %}

    return eval(count=count, index=index + 1);
}
