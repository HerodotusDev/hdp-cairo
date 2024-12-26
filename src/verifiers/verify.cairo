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
    tempvar chain_proofs_len: felt = nondet %{ len(chain_proofs) %};
    let (mmr_meta_idx, _) = run_state_verification_inner(mmr_meta_idx=0, idx=chain_proofs_len);
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
}(mmr_meta_idx: felt, idx: felt) -> (mmr_meta_idx: felt, idx: felt) {
    if (idx == 0) {
        return (mmr_meta_idx=mmr_meta_idx, idx=idx);
    }

    tempvar chain_id: felt = nondet %{ chain_proofs[ids.idx - 1].chain_id %};
    let (chain_info) = fetch_chain_info(chain_id);

    %{ vm_enter_scope({'batch': chain_proofs[ids.idx - 1].value, '__dict_manager': __dict_manager}) %}
    with chain_info {
        let (mmr_meta_idx) = evm_run_state_verification(mmr_meta_idx);
    }
    %{ vm_exit_scope() %}

    return run_state_verification_inner(mmr_meta_idx=mmr_meta_idx, idx=idx - 1);
}
