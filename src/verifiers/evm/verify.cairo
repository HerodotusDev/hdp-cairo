from src.verifiers.evm.account_verifier import verify_accounts
from src.verifiers.evm.storage_item_verifier import verify_storage_items
from src.verifiers.evm.header_verifier import verify_mmr_batches
from src.verifiers.evm.block_tx_verifier import verify_block_tx_proofs
from src.verifiers.evm.receipt_verifier import verify_block_receipt_proofs

from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, KeccakBuiltin

from src.types import MMRMeta, ChainInfo

func run_state_verification{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    evm_memorizer: DictAccess*,
    mmr_metas: MMRMeta*,
    chain_info: ChainInfo,
}(mmr_meta_idx: felt) -> felt {
    alloc_locals;

    // Step 1: Verify MMR and headers inclusion
    let chain_id = chain_info.id;
    with chain_id {
        let (mmr_meta_idx) = verify_mmr_batches(mmr_meta_idx);
    }
    %{ print("evm: mmr_meta_idx: ", ids.mmr_meta_idx) %}

    // Step 2: Verify the accounts
    verify_accounts();

    // Step 3: Verify the storage items
    verify_storage_items();

    // Step 4: Verify the block tx proofs
    verify_block_tx_proofs();

    // Step 5: Verify the block receipt proofs
    verify_block_receipt_proofs();

    return mmr_meta_idx;
}
