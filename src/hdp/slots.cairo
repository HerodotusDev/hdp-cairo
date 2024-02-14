from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from src.libs.mpt import verify_mpt_proof
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.alloc import alloc
from src.hdp.types import AccountState, AccountSlot, AccountSlotProof
from src.hdp.account import get_account_state_root

from src.libs.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_from_le_64_chunks_array,
)

from src.libs.utils import felt_divmod, felt_divmod_8, word_reverse_endian_64

// Intializes and validates the account_slots
func init_account_slots{
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
                memory[account_ptr._reference_value] = account["account_id"]
                memory[account_ptr._reference_value + 1] =segments.gen_arg(account["slot"])
                memory[account_ptr._reference_value + 2] = account["key"]["low"]
                memory[account_ptr._reference_value + 3] = account["key"]["high"]
                memory[account_ptr._reference_value + 4] = len(account["proofs"])
                memory[account_ptr._reference_value + 5] = proofs_ptr._reference_value

            def write_proofs(ptr, proofs):
                offset = 0
                for proof in proofs:
                    memory[ptr._reference_value + offset] = proof["block_number"]
                    memory[ptr._reference_value + offset + 1] = len(proof["proof"])
                    memory[ptr._reference_value + offset + 2] = segments.gen_arg(proof["proof_bytes_len"])
                    memory[ptr._reference_value + offset + 3] = segments.gen_arg(proof["proof"])
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

        return init_account_slots(
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
    accounts_states: AccountState**,
} (
    account_slots: AccountSlot*,
    account_slots_len: felt,
    account_slots_states: AccountState**,
    pow2_array: felt*,
) {
    if(account_slots_len == 0) {
        return ();
    }

    let account_slot_idx = account_slots_len - 1;


    // Question: 
    // Am I supposed to allocate the account_states here? I am not able to make it work without another alloc, but I wonder if im wasting memory here, since I allocated the nested structure already in hdp
    let account_slot_states: AccountState* = alloc();
    
    let states = verify_account_slot(
        account_slot=account_slots[account_slot_idx],
        account_slot_states=account_slot_states,
        proof_idx=0,
        pow2_array=pow2_array,
    );

    assert account_slots_states[account_slot_idx] = states;

    return verify_n_account_slots(
        account_slots=account_slots,
        account_slots_len=account_slots_len - 1,
        account_slots_states=account_slots_states,
        pow2_array=pow2_array,
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
    accounts_states: AccountState**,
} (
    account_slot: AccountSlot,
    account_slot_states: AccountState*,
    proof_idx: felt,
    pow2_array: felt*,
) -> AccountState* {
    alloc_locals;
    if (proof_idx == account_slot.proofs_len) {
        return account_slot_states;
    }

    // get state_root from verified headers
    with pow2_array {
        let state_root = get_account_state_root(accounts_states[account_slot.account_id][account_slot.proofs[proof_idx].block_number].values);
    }
    
    let (value: felt*, value_len: felt) = verify_mpt_proof(
        mpt_proof=account_slot.proofs[proof_idx].proof,
        mpt_proof_bytes_len=account_slot.proofs[proof_idx].proof_bytes_len,
        mpt_proof_len=account_slot.proofs[proof_idx].proof_len,
        key_little=account_slot.key,
        n_nibbles_already_checked=0,
        node_index=0,
        hash_to_assert=state_root,
        pow2_array=pow2_array,
    );

    // write verified account state
    assert account_slot_states[proof_idx] = AccountState(
        values=value,
        values_len=value_len,
    );

    return verify_account_slot(
        account_slot=account_slot,
        account_slot_states=account_slot_states,
        proof_idx=proof_idx + 1,
        pow2_array=pow2_array,
    );
}