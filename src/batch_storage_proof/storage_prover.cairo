%builtins output range_check bitwise keccak poseidon
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.serialize import serialize_word
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash, poseidon_hash_many

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

    let mmr_size = [range_check_ptr];
    let n_proofs = [range_check_ptr + 1];
    %{
        ids.mmr_root = program_input["mmr_root"]
        ids.mmr_size = program_input["mmr_size"]
        segments.write_arg(ids.element_preimages, program_input["element_preimages"])
        segments.write_arg(ids.element_preimages_len, [len(x) for x in program_input["element_preimages"]])
        segments.write_arg(ids.element_positions, program_input["element_positions"])
        segments.write_arg(ids.inclusion_proofs, program_input["inclusion_proofs"])
        ids.n_proofs = len(program_input["inclusion_proofs"])
    %}
    let range_check_ptr = range_check_ptr + 2;

    verify_n_inclusion_proofs(
        element_preimages, element_preimages_len, element_positions, inclusion_proofs, n_proofs - 1
    );

    serialize_word(mmr_root);
    serialize_word(mmr_size);

    return ();
}

func verify_n_inclusion_proofs{poseidon_ptr: PoseidonBuiltin*}(
    element_preimages: felt**,
    element_preimages_len: felt*,
    element_positions: felt*,
    inclusion_proofs: felt**,
    index: felt,
) {
    alloc_locals;
    if (index == -1) {
        return ();
    } else {
        verify_mmr_inclusion_proof(
            element_preimages[index], element_preimages_len[index], inclusion_proofs[index]
        );
        return verify_n_inclusion_proofs(
            element_preimages, element_preimages_len, element_positions, inclusion_proofs, index - 1
        );
    }
}
func verify_mmr_inclusion_proof{poseidon_ptr: PoseidonBuiltin*}(
    element_preimage: felt*, element_preimage_len: felt, inclusion_proof: felt*
) {
    let element = poseidon_hash_many(n=element_preimage_len, elements=element_preimage);
    return ();
}

func batch_serialize_words{output_ptr: felt*}(words: felt*, n_words: felt) {
    if (n_words == 0) {
        return ();
    } else {
        serialize_word([words]);
        return batch_serialize_words(words + 1, n_words - 1);
    }
}
