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

    // batch abstraction will be usefull with multiple chains
    %{ vm_enter_scope({'batch': proofs, '__dict_manager': __dict_manager}) %}

    let (mmr_meta_idx) = evm_run_state_verification(0);

    %{ vm_exit_scope() %}

    return (mmr_metas_len=mmr_meta_idx);
}
