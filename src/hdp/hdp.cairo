%builtins output range_check
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian

func main{
    output_ptr: felt*,
    range_check_ptr,
}() {
    alloc_locals;
    local results_root: Uint256;
    local tasks_root: Uint256; 
    local mmr_root: felt;

    %{
        ids.results_root.low = program_input["resultsRoot"]["low"]
        ids.results_root.high = program_input["resultsRoot"]["high"]
        ids.tasks_root.low = program_input["tasksRoot"]["low"]
        ids.tasks_root.high = program_input["tasksRoot"]["high"]
        ids.mmr_root = program_input["mmrRoot"]
    
    %}

    [ap] = results_root.high;
    [ap] = [output_ptr], ap++;

    [ap] = results_root.low;
    [ap] = [output_ptr + 1], ap++;

    [ap] = tasks_root.high;
    [ap] = [output_ptr + 2], ap++;

    [ap] = tasks_root.low;
    [ap] = [output_ptr + 3], ap++;

    [ap] = mmr_root;
    [ap] = [output_ptr + 4], ap++;

    let output_ptr = output_ptr + 5;

    return();
}