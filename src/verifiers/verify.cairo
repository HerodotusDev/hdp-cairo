from src.verifiers.evm.verify import run_state_verification as evm_run_state_verification
from src.verifiers.starknet.verify import run_state_verification as starknet_run_state_verification
from src.verifiers.injected_state.verify import inclusion_state_verification, non_inclusion_state_verification, update_state_verification
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_builtins import (
    HashBuiltin,
    PoseidonBuiltin,
    BitwiseBuiltin,
    KeccakBuiltin,
    SignatureBuiltin,
    EcOpBuiltin,
)

from src.types import MMRMeta, ChainInfo, InjectedStateInfo
from src.utils.chain_info import fetch_chain_info, Layout
from src.utils.injected_state_info import fetch_injected_state_info, ProofType

func run_chain_state_verification{
    range_check_ptr,
    pedersen_ptr: HashBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    evm_memorizer: DictAccess*,
    starknet_memorizer: DictAccess*,
    injected_state_memorizer: DictAccess*,
    mmr_metas: MMRMeta*,
}() -> (mmr_metas_len: felt) {
    tempvar chain_proofs_len: felt = nondet %{ len(chain_proofs) %};
    let (mmr_meta_idx, _) = run_chain_state_verification_inner(mmr_meta_idx=0, idx=chain_proofs_len);
    return (mmr_metas_len=mmr_meta_idx);
}

func run_chain_state_verification_inner{
    range_check_ptr,
    pedersen_ptr: HashBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    evm_memorizer: DictAccess*,
    starknet_memorizer: DictAccess*,
    injected_state_memorizer: DictAccess*,
    mmr_metas: MMRMeta*,
}(mmr_meta_idx: felt, idx: felt) -> (mmr_meta_idx: felt, idx: felt) {
    alloc_locals;

    if (idx == 0) {
        return (mmr_meta_idx=mmr_meta_idx, idx=idx);
    }

    tempvar chain_id: felt = nondet %{ chain_proofs[ids.idx - 1].chain_id %};
    let (local chain_info) = fetch_chain_info(chain_id);

    if (chain_info.layout == Layout.EVM) {
        with chain_info {
            %{ vm_enter_scope({'batch_evm': chain_proofs[ids.idx - 1].value, '__dict_manager': __dict_manager}) %}
            let (mmr_meta_idx) = evm_run_state_verification(mmr_meta_idx);
            %{ vm_exit_scope() %}

            return run_chain_state_verification_inner(mmr_meta_idx=mmr_meta_idx, idx=idx - 1);
        }
    }

    if (chain_info.layout == Layout.STARKNET) {
        with chain_info {
            %{ vm_enter_scope({'batch_starknet': c1hain_proofs[ids.idx - 1].value, '__dict_manager': __dict_manager}) %}
            let (mmr_meta_idx) = starknet_run_state_verification(mmr_meta_idx);
            %{ vm_exit_scope() %}

            return run_chain_state_verification_inner(mmr_meta_idx=mmr_meta_idx, idx=idx - 1);
        }
    }

    assert 0 = 1;
    return (mmr_meta_idx=0, idx=0);
}

func run_injected_state_verification(
    range_check_ptr,
    pedersen_ptr: HashBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    injected_state_memorizer: DictAccess*,
)(){
    tempvar state_proofs_len: felt = nondet %{ len(state_proofs) %};
    let (_) = run_injected_state_verification_inner(idx=state_proofs_len);
    return ();
}

func run_injected_state_verification_inner{
    range_check_ptr,
    pedersen_ptr: HashBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    injected_state_memorizer: DictAccess*,
}(idx: felt) -> (idx: felt) {
    alloc_locals;

    if (idx == 0) {
        return (idx=idx);
    }

    tempvar proof_type: felt = nondet %{ state_proofs[ids.idx - 1].proof_type %};
    let (local proof_info) = fetch_injected_state_info(proof_type);

    if (proof_info.proof_type == ProofType.INCLUSION) {
        with proof_info {
            %{ vm_enter_scope({'batch_state_server': state_proofs[ids.idx - 1].value, '__dict_manager': __dict_manager}) %}
            let (_) = inclusion_state_verification();
            %{ vm_exit_scope() %}

            return run_injected_state_verification_inner(idx=idx - 1);
        }
    }

    if (proof_info.proof_type == ProofType.NON_INCLUSION) {
        with proof_info {
            %{ vm_enter_scope({'batch_state_server': state_proofs[ids.idx - 1].value, '__dict_manager': __dict_manager}) %}
            let (_) = non_inclusion_state_verification();
            %{ vm_exit_scope() %}
        }

        return run_injected_state_verification_inner(idx=idx - 1);
    }

    if (proof_info.proof_type == ProofType.UPDATE) {
        with proof_info {
            %{ vm_enter_scope({'batch_state_server': state_proofs[ids.idx - 1].value, '__dict_manager': __dict_manager}) %}
            let (_) = update_state_verification();
            %{ vm_exit_scope() %}

            return run_injected_state_verification_inner(idx=idx - 1);
        }
    }

    assert 0 = 1;
    return (idx=0);
}