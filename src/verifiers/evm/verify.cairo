from src.verifiers.evm.account_verifier import verify_accounts
from src.verifiers.evm.storage_item_verifier import verify_storage_items
from src.verifiers.evm.header_verifier import verify_mmr_batches
from src.verifiers.evm.block_tx_verifier import verify_block_tx_proofs
from src.verifiers.evm.receipt_verifier import verify_block_receipt_proofs
from packages.eth_essentials.lib.utils import write_felt_array_to_dict_keys
from starkware.cairo.common.dict import dict_write, dict_read

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
    chain_info: ChainInfo
}(mmr_meta_idx: felt) -> felt {
    alloc_locals;

    // Step 1: Verify MMR and headers inclusion
    let chain_id = chain_info.id;
    with chain_id {
        let (mmr_meta_idx) = verify_mmr_batches(mmr_meta_idx);
    }

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