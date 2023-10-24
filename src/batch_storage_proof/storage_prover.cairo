%builtins output range_check bitwise keccak poseidon
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.serialize import serialize_word
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash, poseidon_hash_many
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_read
from src.libs.utils import pow2alloc127, write_felt_array_to_dict_keys
from src.libs.mmr import (
    compute_peaks_positions,
    assert_mmr_size_is_valid,
    compute_height_pre_alloc_pow2 as compute_height,
)
from src.libs.block_header import extract_state_root_little

const STATE_ROOT_TRIE_TYPE = 0;
const RECEIPTS_ROOT_TRIE_TYPE = 1;

// For now, takes Poseidon MMR inclusion proofs as input and verifies them.
// Later : Associate a storage proof to each MMR inclusion proof.
func main{
    output_ptr: felt*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;
    local mmr_root: felt;
    local mmr_size: felt;
    let (element_preimages: felt**) = alloc();
    let (element_preimages_len: felt*) = alloc();
    let (element_positions: felt*) = alloc();
    let (inclusion_proofs: felt**) = alloc();
    let (inclusion_proofs_len: felt*) = alloc();
    let (trie_types: felt*) = alloc();
    let mmr_size = [range_check_ptr];
    let n_proofs = [range_check_ptr + 1];
    %{
        ids.mmr_root = program_input["mmr_root"]
        ids.mmr_size = program_input["mmr_size"]
        segments.write_arg(ids.element_preimages, program_input["element_preimages"])
        segments.write_arg(ids.element_preimages_len, [len(x) for x in program_input["element_preimages"]])
        segments.write_arg(ids.element_positions, program_input["element_positions"])
        segments.write_arg(ids.inclusion_proofs, program_input["inclusion_proofs"])
        segments.write_arg(ids.inclusion_proofs_len, [len(x) for x in program_input["inclusion_proofs"]])
        segments.write_arg(ids.trie_types, program_input["trie_types"])
        ids.n_proofs = len(program_input["inclusion_proofs"])
    %}
    let range_check_ptr = range_check_ptr + 2;
    let pow2_array: felt* = pow2alloc127();

    with pow2_array {
        assert_mmr_size_is_valid(mmr_size);
        let (peaks: felt*, peaks_len: felt) = compute_peaks_positions(mmr_size);
    }

    let (local peaks_positions_dict) = default_dict_new(default_value=0);
    tempvar peaks_positions_dict_start = peaks_positions_dict;

    write_felt_array_to_dict_keys{dict_end=peaks_positions_dict}(array=peaks, index=peaks_len - 1);
    let rightmost_peak_pos = peaks[peaks_len - 1];
    %{ print(f"Rightmost peak pos : {ids.rightmost_peak_pos}") %}
    verify_n_inclusion_proofs{
        mmr_root=mmr_root,
        mmr_size=mmr_size,
        peaks_positions_dict=peaks_positions_dict,
        rightmost_peak_pos=rightmost_peak_pos,
        pow2_array=pow2_array,
    }(
        element_preimages,
        element_preimages_len,
        element_positions,
        inclusion_proofs,
        inclusion_proofs_len,
        n_proofs - 1,
    );
    let trie_roots: Uint256* = alloc();
    extract_trie_roots{
        block_headers_array=element_preimages, trie_types=trie_types, trie_roots=trie_roots
    }(n_proofs - 1);

    default_dict_finalize(peaks_positions_dict_start, peaks_positions_dict, 0);

    serialize_word(mmr_root);
    serialize_word(mmr_size);

    return ();
}

func verify_n_inclusion_proofs{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    mmr_root: felt,
    mmr_size: felt,
    peaks_positions_dict: DictAccess*,
    rightmost_peak_pos: felt,
    pow2_array: felt*,
}(
    element_preimages: felt**,
    element_preimages_len: felt*,
    element_positions: felt*,
    inclusion_proofs: felt**,
    inclusion_proofs_len: felt*,
    index: felt,
) {
    alloc_locals;
    %{ print(f"Verifying proof {ids.index}") %}
    if (index == -1) {
        return ();
    } else {
        let (element) = poseidon_hash_many(
            n=element_preimages_len[index], elements=element_preimages[index]
        );

        let expected_root = verify_mmr_inclusion_proof(
            element=element,
            height=0,
            position=element_positions[index],
            inclusion_proof=inclusion_proofs[index],
            inclusion_proof_index=0,
            inclusion_proof_len=inclusion_proofs_len[index],
        );
        let (expected_root) = poseidon_hash(mmr_size, expected_root);
        assert expected_root - mmr_root = 0;
        return verify_n_inclusion_proofs(
            element_preimages,
            element_preimages_len,
            element_positions,
            inclusion_proofs,
            inclusion_proofs_len,
            index - 1,
        );
    }
}

func verify_mmr_inclusion_proof{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    peaks_positions_dict: DictAccess*,
    rightmost_peak_pos: felt,
    pow2_array: felt*,
}(
    element: felt,
    height: felt,
    position: felt,
    inclusion_proof: felt*,
    inclusion_proof_index: felt,
    inclusion_proof_len: felt,
) -> felt {
    alloc_locals;
    if (inclusion_proof_index == inclusion_proof_len) {
        return element;
    } else {
        %{ print(f"Proof index: {ids.inclusion_proof_index+1} / {ids.inclusion_proof_len}") %}
        let (is_position_in_peaks) = dict_read{dict_ptr=peaks_positions_dict}(position);
        if (is_position_in_peaks != 0) {
            %{ print(f"\tProof index in peaks") %}
            if (position == rightmost_peak_pos) {
                %{ print(f"\tRightmost peak") %}
                // %{ print(f"hashing last : {memory[ids.inclusion_proof + ids.inclusion_proof_index]},  {ids.element}") %}

                let (element) = poseidon_hash(inclusion_proof[inclusion_proof_index], element);
                tempvar position = position;
            } else {
                // %{ print(f"hashing : {ids.element}, {memory[ids.inclusion_proof + ids.inclusion_proof_index]}") %}

                let (element) = poseidon_hash(element, inclusion_proof[inclusion_proof_index]);
                tempvar position = rightmost_peak_pos;
            }

            return verify_mmr_inclusion_proof(
                element,
                height,
                position,
                inclusion_proof,
                inclusion_proof_index + 1,
                inclusion_proof_len,
            );
        } else {
            let position_height = compute_height(position);
            let next_height = compute_height(position + 1);
            // %{ print(f"position {ids.position}, h={ids.position_height}, nh={ids.next_height}") %}
            if (next_height == position_height + 1) {
                // We are in a right child
                // %{ print(f"hashing right : {memory[ids.inclusion_proof + ids.inclusion_proof_index]}, {ids.element}") %}

                let (element) = poseidon_hash(inclusion_proof[inclusion_proof_index], element);
                return verify_mmr_inclusion_proof(
                    element,
                    height + 1,
                    position + 1,
                    inclusion_proof,
                    inclusion_proof_index + 1,
                    inclusion_proof_len,
                );
            } else {
                // We are in a left child
                // %{ print(f"hashing left : {ids.element}, {memory[ids.inclusion_proof + ids.inclusion_proof_index]}") %}
                let (element) = poseidon_hash(element, inclusion_proof[inclusion_proof_index]);
                tempvar element = element;
                tempvar position = position + pow2_array[height + 1];
                return verify_mmr_inclusion_proof(
                    element,
                    height + 1,
                    position,
                    inclusion_proof,
                    inclusion_proof_index + 1,
                    inclusion_proof_len,
                );
            }
        }
    }
}

// Write trie_roots[index] == extract_root(trie_type[index], block_headers_array[index])
// Where extract_root(trie_type, block_header) gets the root of type trie_type from block_header.
// trie_type is either STATE_ROOT_TRIE_TYPE (0), RECEIPTS_ROOT_TRIE_TYPE (1) or WITHDRAWALS_ROOT_TRIE_TYPE (any other value)
// Implicits arguments:
// - range_check_ptr: The pointer to the range check segment.
// - block_headers_array: Array of pointers to array of felts, each segmenting the block header into 8-byte little endian chunks.
// - trie_types: Array of felts, each containing the type of the trie to extract. (0 for state root, 1 for receipts root, any other value for withdrawals root)
// - trie_roots: Array of Uint256 to write the extracted trie roots to.
// Params:
// - index: The index of the trie to extract.
func extract_trie_roots{
    range_check_ptr, block_headers_array: felt**, trie_types: felt*, trie_roots: Uint256*
}(index: felt) {
    if (index == -1) {
        return ();
    } else {
        if (trie_types[index] == STATE_ROOT_TRIE_TYPE) {
            let trie_root = extract_state_root_little(block_headers_array[index]);
            assert trie_roots[index].low = trie_root.low;
            assert trie_roots[index].high = trie_root.high;
            return extract_trie_roots(index - 1);
        } else {
            if (trie_types[index] == RECEIPTS_ROOT_TRIE_TYPE) {
                // TODO
                tempvar trie_root = Uint256(0, 0);
                assert trie_roots[index].low = trie_root.low;
                assert trie_roots[index].high = trie_root.high;
                return extract_trie_roots(index - 1);
            } else {
                // Withdrawals root
                // TODO
                tempvar trie_root = Uint256(0, 0);
                assert trie_roots[index].low = trie_root.low;
                assert trie_roots[index].high = trie_root.high;
                return extract_trie_roots(index - 1);
            }
        }
    }
}
func batch_serialize_words{output_ptr: felt*}(words: felt*, n_words: felt) {
    if (n_words == 0) {
        return ();
    } else {
        serialize_word([words]);
        return batch_serialize_words(words + 1, n_words - 1);
    }
}
