from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.alloc import alloc
from src.rlp import le_chunks_to_uint256

func main{output_ptr: felt*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}() {
    alloc_locals;

    local program_hash: felt = 0xaf1333b8346c1ac941efe380f3122a71c1f7cbad19301543712e74f765bfca;
    let (local inputs: felt*) = alloc();
    local inputs_len: felt = 3;
    assert inputs[0] = 5186021;
    assert inputs[1] = 5186024;
    assert inputs[2] = 113007187165825507614120510246167695609561346261;

    local program_hash_bit_len;
    %{
        program_hash_bit_len = len(hex(ids.program_hash)) * 4
        print(f"Program hash: {program_hash_bit_len}")
    %}

    return ();
}
