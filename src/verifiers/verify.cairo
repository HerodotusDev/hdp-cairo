from src.verifiers.evm.verify import run_state_verification as evm_run_state_verification
from src.verifiers.starknet.verify import run_state_verification as starknet_run_state_verification
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_builtins import (
    HashBuiltin,
    PoseidonBuiltin,
    BitwiseBuiltin,
    KeccakBuiltin,
    SignatureBuiltin,
    EcOpBuiltin,
)

from src.types import MMRMeta, ChainInfo
from src.utils.chain_info import fetch_chain_info

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
}() -> (mmr_metas_len: felt) {
    alloc_locals;
    local batch_len: felt;
    %{ ids.batch_len = len(proofs) %}

    let (mmr_meta_idx) = run_state_verification_inner(batch_len, 0);
    return (mmr_metas_len=mmr_meta_idx);
}

func run_state_verification_inner{
    range_check_ptr,
    pedersen_ptr: HashBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    evm_memorizer: DictAccess*,
    starknet_memorizer: DictAccess*,
    mmr_metas: MMRMeta*,
}(batch_len: felt, mmr_meta_idx: felt) -> (mmr_meta_idx: felt) {
    alloc_locals;
    if (batch_len == 0) {
        return (mmr_meta_idx=mmr_meta_idx);
    }

    local chain_id: felt;
    %{ ids.chain_id = proofs[ids.batch_len - 1].mmr_meta.chain_id %}

    let (chain_info) = fetch_chain_info(chain_id);

    if (chain_info.layout == 0) {
        %{ vm_enter_scope({'batch': proofs[ids.batch_len - 1], '__dict_manager': __dict_manager}) %}
        with chain_info {
            let mmr_meta_idx = evm_run_state_verification(mmr_meta_idx);
        }
        %{ vm_exit_scope() %}

        return run_state_verification_inner(batch_len=batch_len - 1, mmr_meta_idx=mmr_meta_idx);
    } else {
        %{ vm_enter_scope({'batch': proofs[ids.batch_len - 1], '__dict_manager': __dict_manager}) %}
        with chain_info {
            let mmr_meta_idx = starknet_run_state_verification(mmr_meta_idx);
        }
        %{ vm_exit_scope() %}

        return run_state_verification_inner(batch_len=batch_len - 1, mmr_meta_idx=mmr_meta_idx);
    }
}
