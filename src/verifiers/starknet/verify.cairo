from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_builtins import (
    PoseidonBuiltin,
    HashBuiltin,
    BitwiseBuiltin,
    KeccakBuiltin,
)

from src.verifiers.starknet.header_verifier import verify_mmr_batches
from src.verifiers.starknet.storage_verifier import verify_proofs
from src.types import MMRMeta, ChainInfo

func run_state_verification{
    range_check_ptr,
    pedersen_ptr: HashBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    evm_memorizer: DictAccess*,
    starknet_memorizer: DictAccess*,
    mmr_metas: MMRMeta*,
    chain_info: ChainInfo,
}(mmr_meta_idx: felt) -> (mmr_meta_idx: felt) {
    alloc_locals;

    // Step 1: Verify MMR and headers inclusion
    tempvar n_proofs: felt = nondet %{ len(batch_starknet.headers_with_mmr_starknet) %};
    let (mmr_meta_idx) = verify_mmr_batches(n_proofs, mmr_meta_idx);
    // Step 2: Verify storage slots
    verify_proofs();

    return (mmr_meta_idx=mmr_meta_idx);
}
