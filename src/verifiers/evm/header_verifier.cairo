from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_read, dict_write
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash, poseidon_hash_many
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.default_dict import default_dict_finalize
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.cairo_keccak.keccak import cairo_keccak_bigend as keccak_bigend

from packages.eth_essentials.lib.mmr import hash_subtree_path_poseidon, hash_subtree_path_keccak
from src.types import MMRMetaPoseidon, MMRMetaKeccak, ChainInfo
from src.utils.debug import print_felt_hex, print_string, print_felt

from src.memorizers.evm.memorizer import EvmMemorizer, EvmHashParams
from src.decoders.evm.header_decoder import HeaderDecoder
from src.verifiers.mmr_verifier import validate_poseidon_mmr_meta, validate_keccak_mmr_meta
from src.utils.rlp import get_rlp_len

func verify_mmr_batches{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: felt*,
    pow2_array: felt*,
    evm_memorizer: DictAccess*,
    mmr_metas_poseidon: MMRMetaPoseidon*,
    mmr_metas_keccak: MMRMetaKeccak*,
    chain_info: ChainInfo,
}(idx: felt, mmr_meta_idx_poseidon: felt, mmr_meta_idx_keccak: felt) -> (mmr_meta_idx_poseidon: felt, mmr_meta_idx_keccak: felt) {
    alloc_locals;
    let (__fp__, _) = get_fp_and_pc();

    if (0 == idx) {
        return (mmr_meta_idx_poseidon=mmr_meta_idx_poseidon, mmr_meta_idx_keccak=mmr_meta_idx_keccak);
    }

    %{ memory[ap] = 1 if batch_evm.headers_with_mmr[ids.idx - 1].is_poseidon() else 0 %}
    if ([ap] == 1) {
        %{ vm_enter_scope({'header_evm_with_mmr_poseidon': batch_evm.headers_with_mmr[ids.idx - 1].poseidon, '__dict_manager': __dict_manager}) %}

        local mmr_meta_poseidon: MMRMetaPoseidon = MMRMetaPoseidon(
            id=nondet %{ header_evm_with_mmr_poseidon.mmr_meta.id %},
            root=nondet %{ header_evm_with_mmr_poseidon.mmr_meta.root %},
            size=nondet %{ header_evm_with_mmr_poseidon.mmr_meta.size %},
            chain_id=nondet %{ header_evm_with_mmr_poseidon.mmr_meta.chain_id %},
        );

        let (peaks_poseidon: felt*) = alloc();
        %{ segments.write_arg(ids.peaks_poseidon, header_evm_with_mmr_poseidon.mmr_meta.peaks) %}
        tempvar peaks_len: felt = nondet %{ len(header_evm_with_mmr_poseidon.mmr_meta.peaks) %};

        let (peaks_dict, peaks_dict_start) = validate_poseidon_mmr_meta(&mmr_meta_poseidon, peaks_poseidon, peaks_len);
        assert mmr_metas_poseidon[mmr_meta_idx_poseidon] = mmr_meta_poseidon;
        tempvar n_header_proofs: felt = nondet %{ len(header_evm_with_mmr_poseidon.headers) %};
        verify_headers_with_mmr_peaks_poseidon{mmr_meta_poseidon=mmr_meta_poseidon, peaks_dict=peaks_dict}(n_header_proofs);

        default_dict_finalize(peaks_dict_start, peaks_dict, 0);

        %{ vm_exit_scope() %}
        return verify_mmr_batches(
            idx=idx - 1,
            mmr_meta_idx_poseidon=mmr_meta_idx_poseidon + 1,
            mmr_meta_idx_keccak=mmr_meta_idx_keccak,
        );
    }

    %{ memory[ap] = 1 if batch_evm.headers_with_mmr[ids.idx - 1].is_keccak() else 0 %}
    if ([ap] == 1) {
        %{ vm_enter_scope({'header_evm_with_mmr_keccak': batch_evm.headers_with_mmr[ids.idx - 1].keccak, '__dict_manager': __dict_manager}) %}

        local mmr_meta_keccak: MMRMetaKeccak = MMRMetaKeccak(
            id=nondet %{ header_evm_with_mmr_keccak.mmr_meta.id %},
            root_low=nondet %{ header_evm_with_mmr_keccak.mmr_meta.root_low %},
            root_high=nondet %{ header_evm_with_mmr_keccak.mmr_meta.root_high %},
            size=nondet %{ header_evm_with_mmr_keccak.mmr_meta.size %},
            chain_id=nondet %{ header_evm_with_mmr_keccak.mmr_meta.chain_id %},
        );

        let (peaks_keccak: Uint256*) = alloc();
        %{ segments.write_arg(ids.peaks_keccak, header_evm_with_mmr_keccak.mmr_meta.peaks) %}
        tempvar peaks_len: felt = nondet %{ len(header_evm_with_mmr_keccak.mmr_meta.peaks) %};

        let (peaks_dict, peaks_dict_start) = validate_keccak_mmr_meta(&mmr_meta_keccak, peaks_keccak, peaks_len);
        assert mmr_metas_keccak[mmr_meta_idx_keccak] = mmr_meta_keccak;
        tempvar n_header_proofs: felt = nondet %{ len(header_evm_with_mmr_keccak.headers) %};
        verify_headers_with_mmr_peaks_keccak{mmr_meta_keccak=mmr_meta_keccak, peaks_dict=peaks_dict}(n_header_proofs);

        default_dict_finalize(peaks_dict_start, peaks_dict, 0);

        %{ vm_exit_scope() %}
        return verify_mmr_batches(
            idx=idx - 1,
            mmr_meta_idx_poseidon=mmr_meta_idx_poseidon,
            mmr_meta_idx_keccak=mmr_meta_idx_keccak + 1,
        );
    }
    
    assert 0 = 1;

    %{ vm_exit_scope() %}
    return verify_mmr_batches(
        idx=idx,
        mmr_meta_idx_poseidon=mmr_meta_idx_poseidon,
        mmr_meta_idx_keccak=mmr_meta_idx_keccak,
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
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    evm_memorizer: DictAccess*,
    chain_info: ChainInfo,
    mmr_meta_poseidon: MMRMetaPoseidon,
    peaks_dict: DictAccess*,
}(idx: felt) {
    alloc_locals;
    if (0 == idx) {
        return ();
    }

    %{ header_evm = header_with_mmr_evm_poseidon.headers[ids.idx - 1] %}

    let (rlp) = alloc();
    %{ segments.write_arg(ids.rlp, [int(x, 16) for x in header_evm.rlp]) %}
    tempvar rlp_len: felt = nondet %{ len(header_evm.rlp) %};
    tempvar leaf_idx: felt = nondet %{ len(header_evm.proof.leaf_idx) %};

    // compute the hash of the header
    let (poseidon_hash) = poseidon_hash_many(n=rlp_len, elements=rlp);

    // a header can be the right-most peak
    if (leaf_idx == mmr_meta_poseidon.size) {
        // instead of running an inclusion proof, we ensure its a known peak
        let (contains_peak) = dict_read{dict_ptr=peaks_dict}(poseidon_hash);
        assert contains_peak = 1;

        // add to memorizer
        let block_number = HeaderDecoder.get_block_number(rlp);
        let memorizer_key = EvmHashParams.header(chain_id=chain_info.id, block_number=block_number);
        EvmMemorizer.add(key=memorizer_key, data=rlp);

        return verify_headers_with_mmr_peaks_poseidon(idx=idx - 1);
    }

    let (mmr_path) = alloc();
    tempvar mmr_path_len: felt = nondet %{ len(header_evm.proof.mmr_path) %};
    %{ segments.write_arg(ids.mmr_path, [int(x, 16) for x in header_evm.proof.mmr_path]) %}

    // compute the peak of the header
    let (computed_peak) = hash_subtree_path_poseidon(
        element=poseidon_hash,
        height=0,
        position=leaf_idx,
        inclusion_proof=mmr_path,
        inclusion_proof_len=mmr_path_len,
    );

    // ensure the peak is included in the peaks dict, which contains the peaks of the mmr_root
    let (contains_peak) = dict_read{dict_ptr=peaks_dict}(computed_peak);
    assert contains_peak = 1;

    // add to memorizer
    let block_number = HeaderDecoder.get_block_number(rlp);
    let memorizer_key = EvmHashParams.header(chain_id=chain_info.id, block_number=block_number);
    EvmMemorizer.add(key=memorizer_key, data=rlp);

    return verify_headers_with_mmr_peaks_poseidon(idx=idx - 1);
}

// Guard function that verifies the inclusion of headers in the MMR.
// It ensures:
// 1. The header hash is included in one of the peaks of the MMR.
// 2. The peaks dict contains the computed peak
// The peak checks are performed in isolation, so each MMR batch separately.
// This ensures we dont create a bag of mmr peas from different chains, which are then used to check the header inclusion for every chain
func verify_headers_with_mmr_peaks_keccak{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: felt*,
    pow2_array: felt*,
    evm_memorizer: DictAccess*,
    chain_info: ChainInfo,
    mmr_meta_keccak: MMRMetaKeccak,
    peaks_dict: DictAccess*,
}(idx: felt) {
    alloc_locals;
    if (0 == idx) {
        return ();
    }

    %{ header_evm = header_evm_with_mmr_keccak.headers[ids.idx - 1] %}

    let (rlp) = alloc();
    %{ segments.write_arg(ids.rlp, [int(x, 16) for x in header_evm.rlp]) %}
    tempvar rlp_bytes_len: felt = nondet %{ len(header_evm.rlp.bytes()) %};
    tempvar leaf_idx: felt = nondet %{ len(header_evm.proof.leaf_idx) %};

    // compute the hash of the header
    let (keccak_hash: Uint256) = keccak_bigend(rlp, rlp_bytes_len);

    // a header can be the right-most peak
    if (leaf_idx == mmr_meta_keccak.size) {
        // instead of running an inclusion proof, we ensure its a known peak
        let (key) = poseidon_hash(x=keccak_hash.low, y=keccak_hash.high);
        let (contains_peak) = dict_read{dict_ptr=peaks_dict}(key);
        assert contains_peak = 1;

        // add to memorizer
        let block_number = HeaderDecoder.get_block_number(rlp);
        let memorizer_key = EvmHashParams.header(chain_id=chain_info.id, block_number=block_number);
        EvmMemorizer.add(key=memorizer_key, data=rlp);

        return verify_headers_with_mmr_peaks_keccak(idx=idx - 1);
    }

    let (mmr_path) = alloc();
    tempvar mmr_path_len: felt = nondet %{ len(header_evm.proof.mmr_path) %};
    %{ segments.write_arg(ids.mmr_path, [int(x, 16) for x in header_evm.proof.mmr_path]) %}

    // compute the peak of the header
    let (computed_peak: Uint256) = hash_subtree_path_keccak(
        element=keccak_hash,
        height=0,
        position=leaf_idx,
        inclusion_proof=mmr_path,
        inclusion_proof_len=mmr_path_len,
    );

    // ensure the peak is included in the peaks dict, which contains the peaks of the mmr_root
    let (key) = poseidon_hash(x=computed_peak.low, y=computed_peak.high);
    let (contains_peak) = dict_read{dict_ptr=peaks_dict}(key);
    assert contains_peak = 1;

    // add to memorizer
    let block_number = HeaderDecoder.get_block_number(rlp);
    let memorizer_key = EvmHashParams.header(chain_id=chain_info.id, block_number=block_number);
    EvmMemorizer.add(key=memorizer_key, data=rlp);

    return verify_headers_with_mmr_peaks_keccak(idx=idx - 1);
}
