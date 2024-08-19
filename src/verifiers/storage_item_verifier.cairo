from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.dict_access import DictAccess
from src.mpt import verify_mpt_proof
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.builtin_keccak.keccak import keccak_bigend
from starkware.cairo.common.alloc import alloc
from src.types import ChainInfo
from src.rlp import decode_rlp_word_to_uint256, le_chunks_to_uint256
from packages.eth_essentials.lib.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_from_le_64_chunks_array,
)
from src.converter import le_address_chunks_to_felt
from src.memorizer import StorageMemorizer, AccountMemorizer
from src.decoders.account_decoder import AccountDecoder, AccountField

from packages.eth_essentials.lib.utils import felt_divmod, felt_divmod_8, word_reverse_endian_64

// Verifies the validity of all of the accounts storage_items and writes them to the memorizer
func verify_storage_items{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    account_dict: DictAccess*,
    storage_dict: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}() {
    alloc_locals;
    local n_storage_items: felt;
    %{ ids.n_storage_items = len(program_input["proofs"]["storages"]) %}

    verify_storage_items_inner(n_storage_items, 0);

    return ();
}

func verify_storage_items_inner{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    account_dict: DictAccess*,
    storage_dict: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}(n_storage_items: felt, index: felt) {
    alloc_locals;

    if (n_storage_items == index) {
        return ();
    }

    let (address: felt*) = alloc();
    let (slot: felt*) = alloc();
    local n_proofs: felt;
    local key: Uint256;
    local key_leading_zeros: felt;
    %{
        storage_item = program_input["proofs"]["storages"][ids.index]
        ids.n_proofs = len(storage_item["proofs"])
        segments.write_arg(ids.address, hex_to_int_array(storage_item["address"]))
        segments.write_arg(ids.slot, hex_to_int_array(storage_item["slot"]))
        (key_low, key_high) = split_128(int(storage_item["storage_key"], 16))
        ids.key.low = key_low
        ids.key.high = key_high
        ids.key_leading_zeros = count_leading_zero_nibbles_from_hex(storage_item["storage_key"])
    %}

    // ensure that slot matches the key
    let (hash: Uint256) = keccak_bigend(slot, 32);
    assert key.low = hash.low;
    assert key.high = hash.high;

    // convertes chunks to LE uint256
    let slot_le = le_chunks_to_uint256(slot, 4, 32);
    let (slot_be) = uint256_reverse_endian(slot_le);

    let (felt_address) = le_address_chunks_to_felt(address);

    verify_storage_item(
        address=felt_address,
        slot=slot_be,
        key=key,
        key_leading_zeros=key_leading_zeros,
        n_proofs=n_proofs,
        proof_idx=0,
    );

    return verify_storage_items_inner(n_storage_items=n_storage_items, index=index + 1);
}

func verify_storage_item{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    account_dict: DictAccess*,
    storage_dict: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}(
    address: felt,
    slot: Uint256,
    key: Uint256,
    key_leading_zeros: felt,
    n_proofs: felt,
    proof_idx: felt,
) {
    alloc_locals;

    if (n_proofs == proof_idx) {
        return ();
    }

    local block_number: felt;
    local proof_len: felt;
    let (mpt_proof: felt**) = alloc();
    let (proof_bytes_len: felt*) = alloc();
    %{
        proof = storage_item["proofs"][ids.proof_idx]
        ids.block_number = proof["block_number"]
        segments.write_arg(ids.mpt_proof, nested_hex_to_int_array(proof["proof"]))
        segments.write_arg(ids.proof_bytes_len, proof["proof_bytes_len"])
        ids.proof_len = len(proof["proof"])
    %}

    let (account_rlp) = AccountMemorizer.get(
        chain_id=chain_info.id, block_number=block_number, address=address
    );
    let state_root = AccountDecoder.get_field(account_rlp, AccountField.STATE_ROOT);

    let (rlp: felt*, _value_bytes_len: felt) = verify_mpt_proof(
        mpt_proof=mpt_proof,
        mpt_proof_bytes_len=proof_bytes_len,
        mpt_proof_len=proof_len,
        key_be=key,
        key_be_leading_zeroes_nibbles=key_leading_zeros,
        root=state_root,
        pow2_array=pow2_array,
    );

    StorageMemorizer.add(
        chain_id=chain_info.id,
        block_number=block_number,
        address=address,
        storage_slot=slot,
        rlp=rlp,
    );

    return verify_storage_item(
        address=address,
        slot=slot,
        key=key,
        key_leading_zeros=key_leading_zeros,
        n_proofs=n_proofs,
        proof_idx=proof_idx + 1,
    );
}
