%builtins output range_check poseidon

from starkware.cairo.common.cairo_builtins import PoseidonBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize

from src.hdp.types import HeaderProof, MMRMeta
from src.hdp.mmr import verify_mmr_meta
from src.hdp.header import verify_header_inclusion

from src.libs.utils import (
    pow2alloc127,
    write_felt_array_to_dict_keys
)

func main{
    output_ptr: felt*,
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;
    local results_root: Uint256;
    local tasks_root: Uint256; 
    local header_proofs_len: felt;
    local mmr_meta: MMRMeta;

    let (mmr_peaks: felt*) = alloc();
    let (header_proofs: HeaderProof*) = alloc();
    let (rlp_headers: felt**) = alloc();
    let (mmr_proofs: felt**) = alloc();
    let pow2_array: felt* = pow2alloc127();
 
    %{
        def write_header_proofs(ptr, header_proofs):
            offset = 0
            for header in header_proofs:
                memory[ptr._reference_value + offset] = header["mmr_id"]
                memory[ptr._reference_value + offset + 1] = header["leaf_idx"]
                memory[ptr._reference_value + offset + 2] = len(header["mmr_inclusion_proof"])
                memory[ptr._reference_value + offset + 3] = len(header["rlp_encoded_header"])
                offset += 4 # increment the offset for fixed sized params

        ids.results_root.low = program_input["results_root"]["low"]
        ids.results_root.high = program_input["results_root"]["high"]
        ids.tasks_root.low = program_input["tasks_root"]["low"]
        ids.tasks_root.high = program_input["tasks_root"]["high"]
        
        ids.mmr_meta.mmr_root = program_input['mmr_meta']['mmr_root']
        ids.mmr_meta.mmr_size = program_input['mmr_meta']['mmr_size']
        ids.mmr_meta.mmr_peaks_len = len(program_input['mmr_meta']['mmr_peaks'])

        write_header_proofs(ids.header_proofs, program_input["header_proofs"])
        ids.header_proofs_len = len(program_input["header_proofs"])

        rlp_headers = [
            header_proof['rlp_encoded_header'] 
            for header_proof in program_input['header_proofs']
        ]

        mmr_proofs = [
            header_proof['mmr_inclusion_proof'] 
            for header_proof in program_input['header_proofs']
        ]

        segments.write_arg(ids.rlp_headers, rlp_headers)
        segments.write_arg(ids.mmr_proofs, mmr_proofs)
        segments.write_arg(ids.mmr_peaks, program_input['mmr_meta']['mmr_peaks'])

    %}
    
    // Check 1: Ensure we have a valid pair of mmr_root and peaks
    verify_mmr_meta{pow2_array=pow2_array}(mmr_meta, mmr_peaks);

    // Write the peaks to the dict if valid
    let (local peaks_dict) = default_dict_new(default_value=0);
    tempvar peaks_dict_start = peaks_dict;
    write_felt_array_to_dict_keys{dict_end=peaks_dict}(array=mmr_peaks, index=mmr_meta.mmr_peaks_len - 1);

    // Check 2: Ensure the header is contained in a peak, and that the peak is known
    verify_header_inclusion{
        range_check_ptr=range_check_ptr,
        poseidon_ptr=poseidon_ptr,
        pow2_array=pow2_array,
        peaks_dict=peaks_dict,
    }(
        header_proofs=header_proofs,
        rlp_headers=rlp_headers,
        mmr_proofs=mmr_proofs,
        header_proofs_len=header_proofs_len,
        mmr_size=mmr_meta.mmr_size
    );

    // Post Verification Checks: 
    
    // Ensure dict consistency
    default_dict_finalize(peaks_dict_start, peaks_dict, 0);

    [ap] = mmr_meta.mmr_root;
    [ap] = [output_ptr], ap++;

    [ap] = results_root.low;
    [ap] = [output_ptr + 1], ap++;

    [ap] = results_root.low;
    [ap] = [output_ptr + 2], ap++;

    [ap] = tasks_root.high;
    [ap] = [output_ptr + 3], ap++;

    [ap] = tasks_root.low;
    [ap] = [output_ptr + 4], ap++;

    [ap] = output_ptr + 5, ap++;
    let output_ptr = output_ptr + 5;

    return();
}

// This doesnt work, the issue arises once I try to write mmr_inclusion_proof or rlp header (dynamic sized arrays)
// %{
//      header_proofs = [
//         [
//             header_proof['mmr_id'],
//             header_proof['leaf_idx'],
//             len(header_proof['mmr_inclusion_proof']),
//             len(header_proof['rlp_encoded_header']),
//             header_proof['mmr_inclusion_proof'],
//             header_proof['rlp_encoded_header'],
            
//         ]
//         for header_proof in program_input['header_proofs']
//     ]

//     print(header_proofs)
//     # ids.header_proofs = segments.gen_arg(header_proofs)
//     segments.gen_arg(ids.header_proofs, header_proofs)

// %}