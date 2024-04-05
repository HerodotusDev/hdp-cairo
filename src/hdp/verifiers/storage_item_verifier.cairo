from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.dict_access import DictAccess
from src.libs.mpt import verify_mpt_proof
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.alloc import alloc
from src.hdp.types import AccountValues, StorageItemProof, StorageItem
from src.hdp.rlp import decode_rlp_word_to_uint256
from src.libs.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_from_le_64_chunks_array,
)

from src.hdp.memorizer import StorageMemorizer, AccountMemorizer
from src.hdp.decoders.account_decoder import AccountDecoder

from src.libs.utils import felt_divmod, felt_divmod_8, word_reverse_endian_64

// Intializes and validates the storage_items
func populate_storage_item_segments{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*, 
    keccak_ptr: KeccakBuiltin*
} (storage_items: StorageItem*, n_storage_items: felt, index: felt) {
     alloc_locals;
    if (index == n_storage_items) {
        return ();
    } else {
        local storage_item: StorageItem;
        let (proofs: StorageItemProof*) = alloc();
        
        %{
            def write_storage_item(account_ptr, proofs_ptr, account):
                memory[account_ptr._reference_value] = segments.gen_arg(hex_to_int_array(account["address"]))
                memory[account_ptr._reference_value + 1] =segments.gen_arg(hex_to_int_array(account["slot"]))
                memory[account_ptr._reference_value + 2] = hex_to_int(account["storage_key"]["low"])
                memory[account_ptr._reference_value + 3] = hex_to_int(account["storage_key"]["high"])
                memory[account_ptr._reference_value + 4] = len(account["proofs"])
                memory[account_ptr._reference_value + 5] = proofs_ptr._reference_value

            def write_proofs(ptr, proofs):
                offset = 0
                for proof in proofs:
                    memory[ptr._reference_value + offset] = proof["block_number"]
                    memory[ptr._reference_value + offset + 1] = len(proof["proof"])
                    memory[ptr._reference_value + offset + 2] = segments.gen_arg(proof["proof_bytes_len"])
                    memory[ptr._reference_value + offset + 3] = segments.gen_arg(nested_hex_to_int_array(proof["proof"]))
                    offset += 4

            storage_item = program_input["storages"][ids.index]

            write_proofs(ids.proofs, storage_item["proofs"])
            write_storage_item(ids.storage_item, ids.proofs, storage_item)
        %}

        // ensure that address matches the key
        let (hash: Uint256) = keccak(storage_item.slot, 32);
        assert storage_item.key.low = hash.low;
        assert storage_item.key.high = hash.high;

        assert storage_items[index] = storage_item;

        return populate_storage_item_segments(
            storage_items=storage_items,
            n_storage_items=n_storage_items,
            index=index + 1,
        );
    }
}

// Verifies the validity of all of the accounts storage_items
// Params:
// - storage_items: the storage_items to verify.
// - storage_items_len: the number of storage_items to verify.
// - pow2_array: the array of powers of 2.
func verify_n_storage_items{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*, 
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    account_values: AccountValues*,
    account_dict: DictAccess*,
    storage_dict: DictAccess*,
    pow2_array: felt*,
} (
    storage_items: StorageItem*,
    storage_items_len: felt,
    storage_values: Uint256*,
    state_idx: felt,
) {
    if(storage_items_len == 0) {
        return ();
    }

    let storage_item_idx = storage_items_len - 1;
    
    let state_idx = verify_storage_item(
        storage_item=storage_items[storage_item_idx],
        storage_values=storage_values,
        proof_idx=0,
        state_idx=state_idx
    );

    return verify_n_storage_items(
        storage_items=storage_items,
        storage_items_len=storage_items_len - 1,
        storage_values=storage_values,
        state_idx=state_idx
    );
}

// Verifies the validity of an account's slot_proofs
// Params:
// - storage_item: the storage slot to verify.
// - proof_idx: the index of the proof to verify.
// - pow2_array: the array of powers of 2.
func verify_storage_item{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*, 
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    account_values: AccountValues*,
    account_dict: DictAccess*,
    storage_dict: DictAccess*,
    pow2_array: felt*,
} (
    storage_item: StorageItem,
    storage_values: Uint256*,
    proof_idx: felt,
    state_idx: felt
) -> felt {
    alloc_locals;
    if (proof_idx == storage_item.proofs_len) {
        return state_idx;
    }


    let slot_proof = storage_item.proofs[proof_idx];

    // get state_root from verified headers
    let (account_value) = AccountMemorizer.get(storage_item.address, slot_proof.block_number);
    let state_root = AccountDecoder.get_state_root(account_value.values);
 
    let (value: felt*, value_bytes_len: felt) = verify_mpt_proof(
        mpt_proof=slot_proof.proof,
        mpt_proof_bytes_len=slot_proof.proof_bytes_len,
        mpt_proof_len=slot_proof.proof_len,
        key_little=storage_item.key,
        n_nibbles_already_checked=0,
        node_index=0,
        hash_to_assert=state_root,
        pow2_array=pow2_array,
    );
    
    let decoded_value = decode_rlp_word_to_uint256(value, value_bytes_len);
    assert storage_values[state_idx] = decoded_value;

    StorageMemorizer.add(storage_item.slot, storage_item.address, slot_proof.block_number, state_idx);

    return verify_storage_item(
        storage_item=storage_item,
        storage_values=storage_values,
        proof_idx=proof_idx + 1,
        state_idx=state_idx + 1
    );
}