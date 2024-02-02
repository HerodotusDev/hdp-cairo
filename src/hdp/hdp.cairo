%builtins output range_check poseidon

from starkware.cairo.common.cairo_builtins import PoseidonBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash, poseidon_hash_many

from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian

from src.hdp.types import HeaderProof, MMRMeta
from src.libs.mmr import mmr_root_poseidon

    //             print("offset:", offset)

    //             # write dynamic sized params
    //             offset += write_felt_array(ptr, offset, header["mmr_inclusion_proof"])
    //             print("offset:", offset)
    //             offset += write_felt_array(ptr, offset, header["rlp_encoded_header"])
    //             print("offset:", offset)

    //     def write_felt_array(ptr, offset, array): # this function is the problem, it writes the values instead of the pointers
    //         counter = 0
    //         for felt in array:
    //             memory[ptr._reference_value + offset + counter] = felt
    //             counter += 1

    //         return counter

    //     def print_header_proof(header_proofs, index):
    //         print("mmr_id:", header_proofs[index].mmr_id)
    //         print("leaf_idx:", header_proofs[index].leaf_idx)
    //         print("mmr_inclusion_proof_len:", header_proofs[index].mmr_inclusion_proof_len)
    //         print("rlp_encoded_header_len:", header_proofs[index].rlp_encoded_header_len)
    //         print("mmr_inclusion_proof:", header_proofs[index].mmr_inclusion_proof)
    //         print("rlp_encoded_header:", header_proofs[index].rlp_encoded_header)
    //         #print(header_proof)
    //         # mmr_proof_len = memory[header_proof + 2]
    //         # rlp_header_array_len = memory[header_proof + 3]
    //         # rlp_header = [memory[header_proof + 4 + mmr_proof_len + i] for i in range(rlp_header_array_len)]

    //         # print(rlp_header)
    
    // %}


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

// ensure that a header is the MMR root
func verify_header_inclusion{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
} (header_proofs: HeaderProof*, rlp_headers: felt**, mmr_proofs: felt**, total_headers: felt) {

    if (total_headers == 0) {
        return ();
    }

    let (poseidon_hash) = poseidon_hash_many(n=header_proofs[total_headers - 1].rlp_encoded_header_len, elements=rlp_headers[total_headers - 1]);

    %{
        #print("poseidon_hash:", ids.poseidon_hash)
    %}

    return verify_header_inclusion(
        header_proofs=header_proofs,
        rlp_headers=rlp_headers,
        mmr_proofs=mmr_proofs,
        total_headers=total_headers - 1
    );
}

func verify_mmr_meta{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
} (mmr_meta: MMRMeta, mmr_peaks: felt*) {
    let (mmr_root) = mmr_root_poseidon(mmr_peaks, mmr_meta.mmr_size, mmr_meta.mmr_peaks_len);

    assert mmr_root = mmr_meta.mmr_root;

    return();
}


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
// 
    %{

        def write_header_proofs(ptr, header_proofs):
            offset = 0
            for header in header_proofs:
                memory[ptr._reference_value + offset] = header["mmr_id"]
                memory[ptr._reference_value + offset + 1] = header["leaf_idx"]
                memory[ptr._reference_value + offset + 2] = len(header["mmr_inclusion_proof"])
                memory[ptr._reference_value + offset + 3] = len(header["rlp_encoded_header"])
                offset += 4 # increment the offset for fixed sized params

    %}

    %{
        ids.results_root.low = program_input["results_root"]["low"]
        ids.results_root.high = program_input["results_root"]["high"]
        ids.tasks_root.low = program_input["tasks_root"]["low"]
        ids.tasks_root.high = program_input["tasks_root"]["high"]
        
        ids.mmr_meta.mmr_root = program_input['mmr_meta']['mmr_root']
        ids.mmr_meta.mmr_size = program_input['mmr_meta']['mmr_size']
        ids.mmr_meta.mmr_peaks_len = len(program_input['mmr_meta']['mmr_peaks'])

        ids.header_proofs_len = len(program_input["header_proofs"])

        write_header_proofs(ids.header_proofs, program_input["header_proofs"])

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

    verify_header_inclusion(
        header_proofs=header_proofs,
        rlp_headers=rlp_headers,
        mmr_proofs=mmr_proofs,
        total_headers=header_proofs_len
    );

    verify_mmr_meta(mmr_meta, mmr_peaks);


    [ap] = results_root.high;
    [ap] = [output_ptr], ap++;

    [ap] = results_root.low;
    [ap] = [output_ptr + 1], ap++;

    [ap] = tasks_root.high;
    [ap] = [output_ptr + 2], ap++;

    [ap] = tasks_root.low;
    [ap] = [output_ptr + 3], ap++;

    [ap] = mmr_meta.mmr_root;
    [ap] = [output_ptr + 4], ap++;

    let output_ptr = output_ptr + 5;

    return();
}