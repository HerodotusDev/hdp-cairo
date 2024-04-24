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
        from tools.py.utils import (
            bytes_to_8_bytes_chunks_little,
        )
        input_bytes = bytes.fromhex("000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000005595f50000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000020102000000000000000000000000000000000000000000000000000000000000")
        ids.input_bytes_len = len(input_bytes)

        input_chunks = bytes_to_8_bytes_chunks_little(input_bytes)
        segments.write_arg(ids.input, input_chunks)
    %}

    let (txs_in_block) = init_txs_in_block{pow2_array=pow2_array}(
        input=input, input_bytes_len=input_bytes_len
    );

    assert txs_in_block.target_block = 5608949;
    assert txs_in_block.increment = 20;
    assert txs_in_block.type = 1;
    assert txs_in_block.sampled_property = 2;

    return ();
}
