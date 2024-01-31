%builtins range_check
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian

func main{
    // output_ptr: felt*
    range_check_ptr,
}() {
    alloc_locals;
    local result_root: Uint256;
    local tasks_root: Uint256; 
    local mmr_root: felt;

    %{
        print(program_input)
    
    %}

    return();
}