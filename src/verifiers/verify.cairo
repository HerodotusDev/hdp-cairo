from src.verifiers.evm.verify import run_state_verification as evm_run_state_verification
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
from src.chain_info import fetch_chain_info

func run_state_verification{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    evm_header_dict: DictAccess*,
    evm_account_dict: DictAccess*,
    evm_storage_dict: DictAccess*,
    evm_block_tx_dict: DictAccess*,
    evm_block_receipt_dict: DictAccess*,
    mmr_metas: MMRMeta*,
}() -> (mmr_metas_len: felt) {
    alloc_locals;
    local batch_len: felt;

    let (mmr_meta_idx) = run_state_verification_inner(batch_len, 0);
    return (mmr_metas_len=mmr_meta_idx);
}

func run_state_verification_inner{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    evm_header_dict: DictAccess*,
    evm_account_dict: DictAccess*,
    evm_storage_dict: DictAccess*,
    evm_block_tx_dict: DictAccess*,
    evm_block_receipt_dict: DictAccess*,
    mmr_metas: MMRMeta*,
}(batch_len: felt, mmr_meta_idx: felt) -> (mmr_meta_idx: felt) {
    alloc_locals;
    if (batch_len == 0) {
        return (mmr_meta_idx=mmr_meta_idx);
    }

    local chain_id: felt;
    %{ 
        ids.chain_id = program_input["proofs"][ids.batch_len - 1]["chain_id"]
    %}

    let (chain_info) = fetch_chain_info(chain_id);

    if (chain_info.layout == 0) {
        // EVM
        %{ vm_enter_scope({
            'batch': program_input["proofs"][ids.batch_len - 1],
            '__dict_manager': __dict_manager
        }) %}
        with chain_info {
            let added_mmrs = evm_run_state_verification(mmr_meta_idx);
        }
        %{ vm_exit_scope() %}

        return run_state_verification_inner(batch_len - 1, mmr_meta_idx=mmr_meta_idx + added_mmrs);
    } 

    assert 1 = 0;
    return (mmr_meta_idx=0);
    // else {
    //     // STARKNET
    //     return run_state_verification_inner(batch_len - 1, mmr_meta_idx=mmr_meta_idx);
    // }
}