from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, HashBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_read
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many
from starkware.cairo.common.default_dict import default_dict_finalize
from starkware.cairo.common.hash_state import hash_felts_no_padding
from packages.eth_essentials.lib.mmr import hash_subtree_path_poseidon
from src.types import MMRMetaPoseidon, ChainInfo
from src.memorizers.starknet.memorizer import StarknetMemorizer, StarknetHashParams
from src.decoders.starknet.header_decoder import StarknetHeaderDecoder, StarknetHeaderFields
from src.verifiers.mmr_verifier import validate_poseidon_mmr_meta

func verify_mmr_batches{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    pedersen_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    starknet_memorizer: DictAccess*,
    mmr_metas_poseidon: MMRMetaPoseidon*,
    chain_info: ChainInfo,
}(idx: felt, mmr_meta_idx_poseidon: felt) -> (mmr_meta_idx_poseidon: felt) {
    alloc_locals;
    let (__fp__, _) = get_fp_and_pc();

    if (0 == idx) {
        return (mmr_meta_idx_poseidon=mmr_meta_idx_poseidon);
    }

    %{ memory[ap] = 1 if batch_starknet.headers_with_mmr[ids.idx - 1].is_poseidon() else 0 %}
    if ([ap] == 1) {
        %{ vm_enter_scope({'header_starknet_with_mmr_poseidon': batch_starknet.headers_with_mmr[ids.idx - 1].poseidon, '__dict_manager': __dict_manager}) %}

        local mmr_meta_poseidon: MMRMetaPoseidon = MMRMetaPoseidon(
            id=nondet %{ header_starknet_with_mmr_poseidon.mmr_meta.id %},
            root=nondet %{ header_starknet_with_mmr_poseidon.mmr_meta.root %},
            size=nondet %{ header_starknet_with_mmr_poseidon.mmr_meta.size %},
            chain_id=nondet %{ header_starknet_with_mmr_poseidon.mmr_meta.chain_id %},
        );

        let (peaks_poseidon: felt*) = alloc();
        %{ segments.write_arg(ids.peaks_poseidon, header_starknet_with_mmr_poseidon.mmr_meta.peaks) %}
        tempvar peaks_len: felt = nondet %{ len(header_starknet_with_mmr_poseidon.mmr_meta.peaks) %};

        let (peaks_dict, peaks_dict_start) = validate_poseidon_mmr_meta(&mmr_meta_poseidon, peaks_poseidon, peaks_len);
        assert mmr_metas_poseidon[mmr_meta_idx_poseidon] = mmr_meta_poseidon;
        tempvar n_header_proofs: felt = nondet %{ len(header_evm_with_mmr_poseidon.headers) %};
        verify_headers_with_mmr_peaks_poseidon{mmr_meta_poseidon=mmr_meta_poseidon, peaks_dict=peaks_dict}(n_header_proofs);

        default_dict_finalize(peaks_dict_start, peaks_dict, 0);

        %{ vm_exit_scope() %}
        return verify_mmr_batches(
            idx=idx - 1,
            mmr_meta_idx_poseidon=mmr_meta_idx_poseidon + 1,
        );
    }
    
    assert 0 = 1;

    %{ vm_exit_scope() %}
    return verify_mmr_batches(
        idx=idx,
        mmr_meta_idx_poseidon=mmr_meta_idx_poseidon,
    );
}

// Guard function that verifies the inclusion of headers in the MMR.
// It ensures:
// 1. The header hash is included in one of the peaks of the MMR.
// 2. The peaks dict contains the computed peak
// The peak checks are performed in isolation, so each MMR batch separately.
// This ensures we dont create a bag of mmr peas from different chains, which are then used to check the header inclusion for every chain
func verify_headers_with_mmr_peaks_poseidon{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    pedersen_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    starknet_memorizer: DictAccess*,
    chain_info: ChainInfo,
    mmr_meta_poseidon: MMRMetaPoseidon,
    peaks_dict: DictAccess*,
}(idx: felt) {
    alloc_locals;
    if (0 == idx) {
        return ();
    }

    %{ header_starknet = header_starknet_with_mmr_poseidon.headers[ids.idx - 1] %}

    let (fields) = alloc();
    %{ segments.write_arg(ids.fields, [int(x, 16) for x in header_starknet.fields]) %}
    tempvar fields_len: felt = nondet %{ len(header_starknet.fields) %};
    tempvar leaf_idx: felt = nondet %{ len(header_starknet.proof.leaf_idx) %};

    // compute the hash of the header
    let (block_hash) = compute_blockhash(fields);

    // a header can be the right-most peak
    if (leaf_idx == mmr_meta_poseidon.size) {
        // instead of running an inclusion proof, we ensure its a known peak
        let (contains_peak) = dict_read{dict_ptr=peaks_dict}(block_hash);
        assert contains_peak = 1;

        // add to memorizer
        // we prefix the fields with its length to make it retrievable from the memorizer
        let (length_and_fields: felt*) = alloc();
        assert length_and_fields[0] = fields_len;
        memcpy(length_and_fields + 1, fields, fields_len);

        let (block_number) = StarknetHeaderDecoder.get_field(
            length_and_fields, StarknetHeaderFields.BLOCK_NUMBER
        );
        let memorizer_key = StarknetHashParams.header(
            chain_id=chain_info.id, block_number=block_number
        );
        StarknetMemorizer.add(key=memorizer_key, data=length_and_fields);

        return verify_headers_with_mmr_peaks_poseidon(idx=idx - 1);
    }

    let (mmr_path) = alloc();
    %{ segments.write_arg(ids.mmr_path, [int(x, 16) for x in header_starknet.proof.mmr_path]) %}
    tempvar mmr_path_len: felt = nondet %{ len(header_starknet.proof.mmr_path) %};

    // compute the peak of the header
    let (computed_peak) = hash_subtree_path_poseidon(
        element=block_hash,
        height=0,
        position=leaf_idx,
        inclusion_proof=mmr_path,
        inclusion_proof_len=mmr_path_len,
    );

    // ensure the peak is included in the peaks dict, which contains the peaks of the mmr_root
    let (contains_peak) = dict_read{dict_ptr=peaks_dict}(computed_peak);
    assert contains_peak = 1;

    // add to memorizer
    // we prefix the fields with its length to make it retrievable from the memorizer
    let (length_and_fields: felt*) = alloc();
    assert length_and_fields[0] = fields_len;
    memcpy(length_and_fields + 1, fields, fields_len);

    let (block_number) = StarknetHeaderDecoder.get_field(
        length_and_fields, StarknetHeaderFields.BLOCK_NUMBER
    );
    let memorizer_key = StarknetHashParams.header(
        chain_id=chain_info.id, block_number=block_number
    );
    StarknetMemorizer.add(key=memorizer_key, data=length_and_fields);

    return verify_headers_with_mmr_peaks_poseidon(idx=idx - 1);
}

func compute_blockhash{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pedersen_ptr: HashBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}(blockhash_preimage: felt*) -> (res: felt) {
    if (blockhash_preimage[0] == 0x535441524B4E45545F424C4F434B5F4841534830) {
        let (blockhash) = poseidon_hash_many(n=17, elements=blockhash_preimage);
        return (res=blockhash);
    }
    if (blockhash_preimage[0] == 0x535441524B4E45545F424C4F434B5F4841534831) {
        let (blockhash) = poseidon_hash_many(n=14, elements=blockhash_preimage);
        return (res=blockhash);
    }
    let initial_hash = [blockhash_preimage];
    let hash_ptr = pedersen_ptr;
    with hash_ptr {
        let (blockhash) = hash_felts_no_padding(
            data_ptr=blockhash_preimage + 1, data_length=12, initial_hash=initial_hash
        );
    }
    let pedersen_ptr = hash_ptr;
    return (res=blockhash);
}
