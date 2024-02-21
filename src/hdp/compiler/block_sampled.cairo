%builtins range_check bitwise keccak

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.builtin_keccak.keccak import keccak
// func decode_block_sampled {
//     range_check_ptr,
//     keccak_ptr
// } () -> BlockSampled {


//     local block_sampled = 
// }

func hash_block_sampled{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*
} (input: felt*, input_bytes_len: felt) -> (hash: Uint256) {
    alloc_locals;

    let (hash: Uint256) = keccak(input, input_bytes_len);

    %{
        print(f"hash_block_sampled: {hex(ids.hash.high)} {hex(ids.hash.low)}")
    %}

    return (hash=hash);
}



func main{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
}() {
    alloc_locals;

    local input: felt*;
    local input_bytes_len: felt;

    %{
        from tools.py.utils import (
            bytes_to_8_bytes_chunks_little,
        )

        dl_slim_bytes =bytes.fromhex("000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009eb09c00000000000000000000000000000000000000000000000000000000009eb100000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000035035b38da6a701c568545dcfcb03fcb875f56beddc4339bee47335c234581644b387f7f0d28db05ad5b092e1152fc70647d559cef220000000000000000000000")
        ids.input = segments.gen_arg(bytes_to_8_bytes_chunks_little(dl_slim_bytes))
        ids.input_bytes_len = len(dl_slim_bytes)
    %}

    let (hash) = hash_block_sampled{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr   
    }(input=input, input_bytes_len=input_bytes_len);

    return ();

}