from src.verifiers.account_verifier import verify_accounts
from src.verifiers.storage_item_verifier import (
    populate_storage_item_segments,
    verify_n_storage_items,
)
from src.verifiers.header_verifier import verify_headers_inclusion
from src.verifiers.mmr_verifier import verify_mmr_meta
from src.verifiers.block_tx_verifier import verify_n_block_tx_proofs
from src.verifiers.receipt_verifier import verify_n_receipt_proofs
from packages.eth_essentials.lib.utils import write_felt_array_to_dict_keys

from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_builtins import (
    HashBuiltin,
    PoseidonBuiltin,
    BitwiseBuiltin,
    KeccakBuiltin,
    SignatureBuiltin,
    EcOpBuiltin,
)

from src.types import (
    MMRMeta,
    ChainInfo
)

func run_state_verification{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    peaks_dict: DictAccess*,
    header_dict: DictAccess*,
    account_dict: DictAccess*,
    storage_dict: DictAccess*,
    block_tx_dict: DictAccess*,
    block_receipt_dict: DictAccess*,
    mmr_meta: MMRMeta,
    chain_info: ChainInfo
}() {
    alloc_locals;
    // Step 1: Verify the MMR meta and store peaks
    verify_mmr_meta();
    write_felt_array_to_dict_keys{dict_end=peaks_dict}(
        array=mmr_meta.peaks, index=mmr_meta.peaks_len - 1
    );

    // Step 2: Verify the headers inclusion
    verify_headers_inclusion();

    verify_accounts();

    return ();
}

