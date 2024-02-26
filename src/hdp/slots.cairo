from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.dict_access import DictAccess
from src.libs.mpt import verify_mpt_proof
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.alloc import alloc
from src.hdp.types import AccountState, AccountSlotProof, SlotState, AccountSlot
from src.hdp.account import AccountReader

from src.libs.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_from_le_64_chunks_array,
)

from src.hdp.memorizer import SlotMemorizer, AccountMemorizer

from src.libs.utils import felt_divmod, felt_divmod_8, word_reverse_endian_64

// Intializes and validates the account_slots
func populate_account_slot_segments{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*, 
    keccak_ptr: KeccakBuiltin*
} (account_slots: AccountSlot*, n_account_slots: felt, index: felt) {
     alloc_locals;
    if (index == n_account_slots) {
        return ();
    } else {
        local account_slot: AccountSlot;
        let (proofs: AccountSlotProof*) = alloc();
        
        %{
            def write_account_slot(account_ptr, proofs_ptr, account):
                memory[account_ptr._reference_value] = segments.gen_arg(hex_to_int_array(account["address"]))
                memory[account_ptr._reference_value + 1] =segments.gen_arg(hex_to_int_array(account["slot"]))
                memory[account_ptr._reference_value + 2] = hex_to_int(account["key"]["low"])
                memory[account_ptr._reference_value + 3] = hex_to_int(account["key"]["high"])
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

            account_slot = program_input['header_batches'][0]["account_slots"][ids.index]

            write_proofs(ids.proofs, account_slot["proofs"])
            write_account_slot(ids.account_slot, ids.proofs, account_slot)
        %}

        // ensure that address matches the key
        let (hash: Uint256) = keccak(account_slot.slot, 32);
        assert account_slot.key.low = hash.low;
        assert account_slot.key.high = hash.high;

        assert account_slots[index] = account_slot;

        return populate_account_slot_segments(
            account_slots=account_slots,
            n_account_slots=n_account_slots,
            index=index + 1,
        );
    }
}

// Verifies the validity of all of the accounts account_slots
// Params:
// - account_slots: the account_slots to verify.
// - account_slots_len: the number of account_slots to verify.
// - pow2_array: the array of powers of 2.
func verify_n_account_slots{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*, 
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    account_states: AccountState*,
    account_dict: DictAccess*,
    slot_dict: DictAccess*,
    pow2_array: felt*,
} (
    account_slots: AccountSlot*,
    account_slots_len: felt,
    slot_states: SlotState*,
    state_idx: felt,
) {
    if(account_slots_len == 0) {
        return ();
    }

    let account_slot_idx = account_slots_len - 1;
    
    let state_idx = verify_account_slot(
        account_slot=account_slots[account_slot_idx],
        slot_states=slot_states,
        proof_idx=0,
        state_idx=state_idx
    );

    return verify_n_account_slots(
        account_slots=account_slots,
        account_slots_len=account_slots_len - 1,
        slot_states=slot_states,
        state_idx=state_idx
    );
}

// Verifies the validity of an account's slot_proofs
// Params:
// - account_slot: the slot to verify.
// - proof_idx: the index of the proof to verify.
// - pow2_array: the array of powers of 2.
func verify_account_slot{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*, 
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    account_states: AccountState*,
    account_dict: DictAccess*,
    slot_dict: DictAccess*,
    pow2_array: felt*,
} (
    account_slot: AccountSlot,
    slot_states: SlotState*,
    proof_idx: felt,
    state_idx: felt
) -> felt {
    alloc_locals;
    if (proof_idx == account_slot.proofs_len) {
        return state_idx;
    }

    let slot_proof = account_slot.proofs[proof_idx];

    // get state_root from verified headers
    let (account_state) = AccountMemorizer.get(account_slot.address, slot_proof.block_number);
    let state_root = AccountReader.get_state_root(account_state.values);
 
    let (value: felt*, _value_len: felt) = verify_mpt_proof(
        mpt_proof=slot_proof.proof,
        mpt_proof_bytes_len=slot_proof.proof_bytes_len,
        mpt_proof_len=slot_proof.proof_len,
        key_little=account_slot.key,
        n_nibbles_already_checked=0,
        node_index=0,
        hash_to_assert=state_root,
        pow2_array=pow2_array,
    );

    // write verified account state
    assert slot_states[state_idx] = SlotState(
        low=value[0], // EVM word is always 32 bytes
        high=value[1],
    );

    SlotMemorizer.add(account_slot.key, account_slot.address, slot_proof.block_number, state_idx);

    return verify_account_slot(
        account_slot=account_slot,
        slot_states=slot_states,
        proof_idx=proof_idx + 1,
        state_idx=state_idx + 1
    );
}