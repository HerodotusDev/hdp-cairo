from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.dict_access import DictAccess
from src.utils.mpt import verify_mpt_proof
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.builtin_keccak.keccak import keccak_bigend
from starkware.cairo.common.alloc import alloc
from src.types import ChainInfo
from src.utils.rlp import decode_rlp_word_to_uint256, le_chunks_to_uint256
from packages.eth_essentials.lib.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_from_le_64_chunks_array,
)
from src.utils.converter import le_address_chunks_to_felt
from src.memorizers.evm.memorizer import EvmMemorizer, EvmHashParams
from src.decoders.evm.account_decoder import AccountDecoder, AccountField, AccountKey
from starkware.cairo.common.registers import get_fp_and_pc

from packages.eth_essentials.lib.utils import felt_divmod, felt_divmod_8, word_reverse_endian_64

// Verifies the validity of all of the accounts storage_items and writes them to the memorizer
func verify_storage_items{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    evm_memorizer: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}() {
    alloc_locals;

    tempvar n_storage_items: felt = nondet %{ len(batch_evm.storages) %};
    verify_storage_items_inner(n_storage_items, 0);

    return ();
}

func verify_storage_items_inner{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    evm_memorizer: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}(n_storage_items: felt, idx: felt) {
    alloc_locals;

    if (n_storage_items == idx) {
        return ();
    }

    let (address: felt*) = alloc();
    %{
        storage_evm = batch_evm.storages[ids.idx]
        segments.write_arg(ids.address, [int(x, 16) for x in storage_evm.address]))
    %}

    let (slot: felt*) = alloc();
    %{ segments.write_arg(ids.slot, [int(x, 16) for x in storage_evm.slot])) %}

    local key: Uint256;
    %{ (ids.key.low, ids.key.high) = split_128(int(storage_evm.storage_key, 16)) %}

    local key_leading_zeros: felt;
    %{ ids.key_leading_zeros = len(storage_evm.storage_key.lstrip("0x")) - len(storage_evm.storage_key.lstrip("0x").lstrip("0")) %}

    // ensure that slot matches the key
    let (hash: Uint256) = keccak_bigend(slot, 32);
    assert key.low = hash.low;
    assert key.high = hash.high;

    // converts chunks to LE uint256
    let slot_le = le_chunks_to_uint256(slot, 4, 32);
    let (slot_be) = uint256_reverse_endian(slot_le);

    let (felt_address) = le_address_chunks_to_felt(address);

    tempvar n_proofs: felt = nondet %{ len(storage_evm.proofs) %};
    verify_storage_item(
        address=felt_address,
        slot=slot_be,
        key=key,
        key_leading_zeros=key_leading_zeros,
        n_proofs=n_proofs,
        idx=0,
    );

    return verify_storage_items_inner(n_storage_items=n_storage_items, idx=idx + 1);
}

func verify_storage_item{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    evm_memorizer: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}(address: felt, slot: Uint256, key: Uint256, key_leading_zeros: felt, n_proofs: felt, idx: felt) {
    alloc_locals;
    let (__fp__, _) = get_fp_and_pc();

    if (n_proofs == idx) {
        return ();
    }

    %{ proof = storage_evm.proofs[ids.idx] %}
    tempvar proof_len: felt = nondet %{ len(proof.proof) %};
    tempvar block_number: felt = nondet %{ proof.block_number %};

    let (proof_bytes_len: felt*) = alloc();
    %{ segments.write_arg(ids.proof_bytes_len, proof.proof_bytes_len) %}

    let (mpt_proof: felt**) = alloc();
    %{ segments.write_arg(ids.mpt_proof, [int(x, 16) for x in proof.proof]) %}

    local account_key: AccountKey = AccountKey(chain_id=chain_info.id, block_number=block_number, address=address);
    let memorizer_key = EvmHashParams.account(
        chain_id=chain_info.id, block_number=block_number, address=address
    );
    let (account_rlp) = EvmMemorizer.get(key=memorizer_key);
    let (state_root: Uint256*, _) = AccountDecoder.get_field(account_rlp, AccountField.STATE_ROOT, &account_key);

    let (rlp: felt*, _value_bytes_len: felt) = verify_mpt_proof(
        mpt_proof=mpt_proof,
        mpt_proof_bytes_len=proof_bytes_len,
        mpt_proof_len=proof_len,
        key_be=key,
        key_be_leading_zeroes_nibbles=key_leading_zeros,
        root=Uint256(low=state_root.low, high=state_root.high),
        pow2_array=pow2_array,
    );

    let memorizer_key = EvmHashParams.storage(
        chain_id=chain_info.id, block_number=block_number, address=address, storage_slot=slot
    );
    EvmMemorizer.add(key=memorizer_key, data=rlp);

    return verify_storage_item(
        address=address,
        slot=slot,
        key=key,
        key_leading_zeros=key_leading_zeros,
        n_proofs=n_proofs,
        idx=idx + 1,
    );
}
