// Storage implementation using Pure Cairo DictAccess
// Compatibility with Rust VM for sound-run

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_read, dict_write
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.alloc import alloc
from src.evm.memory import Memory
from src.evm.context import EvmExecutionContext
from src.memorizers.evm.memorizer import EvmPackParams
from src.memorizers.evm.state_access import EvmStateAccess, EvmStateAccessType

// Labels for hashing to avoid collisions
const STORAGE_TAG = 'evm_storage_v1';
const METADATA_TAG = 'evm_metadata_v1';

// Metadata IDs
const RETURN_OFFSET_ID = 1;
const RETURN_SIZE_ID = 2;

// Helper to hash storage key with part selector (0 for low, 1 for high)
func _hash_storage_key{poseidon_ptr: PoseidonBuiltin*}(
    address: felt, key_low: felt, key_high: felt, part: felt
) -> (hash: felt) {
    let (data: felt*) = alloc();
    assert data[0] = STORAGE_TAG;
    assert data[1] = address;
    assert data[2] = key_low;
    assert data[3] = key_high;
    assert data[4] = part;
    let (h) = poseidon_hash_many(5, data);
    return (hash=h);
}

// Helper to hash metadata key
func _hash_metadata_key{poseidon_ptr: PoseidonBuiltin*}(field_id: felt) -> (hash: felt) {
    let (data: felt*) = alloc();
    assert data[0] = METADATA_TAG;
    assert data[1] = field_id;
    let (h) = poseidon_hash_many(2, data);
    return (hash=h);
}

// Load from storage
func storage_load{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    evm_storage: DictAccess*,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    evm_memorizer: DictAccess*,
    evm_decoder_ptr: felt**,
    evm_key_hasher_ptr: felt**,
    pow2_array: felt*
}(
    ctx: EvmExecutionContext,
    address: felt, 
    key_low: felt, 
    key_high: felt
) -> (value: Uint256) {
    alloc_locals;
    let (h_low) = _hash_storage_key(address, key_low, key_high, 0);
    let (h_high) = _hash_storage_key(address, key_low, key_high, 1);
    
    let (v_low) = dict_read{dict_ptr=evm_storage}(h_low);
    let (v_high) = dict_read{dict_ptr=evm_storage}(h_high);
    
    // If we have a non-zero value in either part, return it.
    if (v_low + v_high != 0) {
        return (value=Uint256(low=v_low, high=v_high));
    }
    
    // Fallback to Memorizer (historical state)
    let (params: felt*) = alloc();
    assert params[0] = ctx.chain_id;
    assert params[1] = ctx.block_number;
    assert params[2] = address;
    assert params[3] = key_high;
    assert params[4] = key_low;
    
    let (local output: felt*) = alloc();
    let keccak_ptr_f = cast(keccak_ptr, felt*);
    let (local res_len) = EvmStateAccess.read_and_decode{keccak_ptr=keccak_ptr_f, output_ptr=output}(
        params=params, 
        state_access_type=EvmStateAccessType.STORAGE, 
        field=0 
    );
    let keccak_ptr = cast(keccak_ptr_f, KeccakBuiltin*);
    
    if (res_len == 0) {
        return (value=Uint256(low=0, high=0));
    }
    
    return (value=Uint256(low=output[0], high=output[1]));
}

// Store to storage
func storage_store{
    poseidon_ptr: PoseidonBuiltin*,
    evm_storage: DictAccess*,
}(address: felt, key_low: felt, key_high: felt, value_low: felt, value_high: felt) {
    alloc_locals;
    let (h_low) = _hash_storage_key(address, key_low, key_high, 0);
    let (h_high) = _hash_storage_key(address, key_low, key_high, 1);
    
    dict_write{dict_ptr=evm_storage}(h_low, value_low);
    dict_write{dict_ptr=evm_storage}(h_high, value_high);
    return ();
}

// Reset storage (returns a new dict)
func storage_init() -> (evm_storage: DictAccess*) {
    let (d: DictAccess*) = default_dict_new(0);
    return (evm_storage=d);
}

// Set returndata size directly
func storage_set_returndata_size{
    poseidon_ptr: PoseidonBuiltin*,
    evm_storage: DictAccess*,
}(size: felt) {
    let (h) = _hash_metadata_key(RETURN_SIZE_ID);
    dict_write{dict_ptr=evm_storage}(h, size);
    return ();
}

// Get returndata size
func storage_get_returndata_size{
    poseidon_ptr: PoseidonBuiltin*,
    evm_storage: DictAccess*,
}() -> (size: felt) {
    let (h) = _hash_metadata_key(RETURN_SIZE_ID);
    let (val) = dict_read{dict_ptr=evm_storage}(h);
    return (size=val);
}

// Set return offset and size
func storage_set_return_data{
    poseidon_ptr: PoseidonBuiltin*,
    evm_storage: DictAccess*,
}(offset: felt, size: felt) {
    alloc_locals;
    let (local h_off) = _hash_metadata_key(RETURN_OFFSET_ID);
    let (h_size) = _hash_metadata_key(RETURN_SIZE_ID);
    dict_write{dict_ptr=evm_storage}(h_off, offset);
    dict_write{dict_ptr=evm_storage}(h_size, size);
    return ();
}

// Get return offset
func storage_get_return_offset{
    poseidon_ptr: PoseidonBuiltin*,
    evm_storage: DictAccess*,
}() -> (offset: felt) {
    let (h) = _hash_metadata_key(RETURN_OFFSET_ID);
    let (val) = dict_read{dict_ptr=evm_storage}(h);
    return (offset=val);
}

// Get return size (redundant helper)
func storage_get_return_size{
    poseidon_ptr: PoseidonBuiltin*,
    evm_storage: DictAccess*,
}() -> (size: felt) {
    let (h) = _hash_metadata_key(RETURN_SIZE_ID);
    let (val) = dict_read{dict_ptr=evm_storage}(h);
    return (size=val);
}

// Set full returndata by copying from memory to dictionary
func storage_set_returndata{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    evm_storage: DictAccess*,
}(child_memory: Memory, offset: felt, size: felt) {
    alloc_locals;
    // Update metadata
    let (h_size) = _hash_metadata_key(RETURN_SIZE_ID);
    dict_write{dict_ptr=evm_storage}(h_size, size);
    
    // Copy bytes to buffer tag entries
    if (size == 0) {
        return ();
    }
    
    _copy_to_returndata_loop(child_memory, offset, size, 0);
    return ();
}

// Internal loop for copying memory to returndata buffer
func _copy_to_returndata_loop{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    evm_storage: DictAccess*,
}(memory: Memory, src_off: felt, count: felt, dst_idx: felt) {
    if (count == 0) {
        return ();
    }
    alloc_locals;
    let (val) = memory_load_byte(memory, src_off);
    let (h) = _hash_returndata_key(dst_idx);
    dict_write{dict_ptr=evm_storage}(h, val);
    
    return _copy_to_returndata_loop(memory, src_off + 1, count - 1, dst_idx + 1);
}

// Helper for returndata hashing
func _hash_returndata_key{poseidon_ptr: PoseidonBuiltin*}(index: felt) -> (hash: felt) {
    let (data: felt*) = alloc();
    assert data[0] = 'evm_returndata_v1';
    assert data[1] = index;
    let (h) = poseidon_hash_many(2, data);
    return (hash=h);
}

// Copy from persistent returndata buffer to memory
func storage_copy_returndata{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    evm_storage: DictAccess*,
}(memory: Memory, dest_off: felt, src_off: felt, count: felt) -> (new_memory: Memory) {
    if (count == 0) {
        return (new_memory=memory);
    }
    alloc_locals;
    let (h) = _hash_returndata_key(src_off);
    let (val) = dict_read{dict_ptr=evm_storage}(h);
    
    let (m1) = memory_store_byte(memory, dest_off, val);
    
    return storage_copy_returndata(m1, dest_off + 1, src_off + 1, count - 1);
}

// Memory imports needed for the loops
from src.evm.memory import memory_load_byte, memory_store_byte

