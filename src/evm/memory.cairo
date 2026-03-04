// Memory with Small Cache
// Uses a fixed-size cache for recent addresses + log fallback
// Cache hit = O(1), Cache miss = O(log_size) but rare for typical EVM

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le

// Cache size - tune this for memory vs speed tradeoff
const CACHE_SIZE = 16;

struct Memory {
    // Log: (addr, low, high) per entry
    log: felt*,
    log_count: felt,
    // Small cache: most recently accessed addresses
    // Layout: [addr0, low0, high0, addr1, low1, high1, ...]
    cache: felt*,
    cache_count: felt,  // How many cache entries are used (max CACHE_SIZE)
}

func memory_new() -> (memory: Memory) {
    let (log) = alloc();
    let (cache) = alloc();
    return (memory=Memory(log=log, log_count=0, cache=cache, cache_count=0));
}

// Store a value - O(cache_size) for cache update
func memory_store{range_check_ptr}(
    memory: Memory, offset: felt, value: Uint256
) -> (new_memory: Memory) {
    alloc_locals;
    
    // Add to log (always append)
    let log_idx = memory.log_count * 3;
    assert [memory.log + log_idx] = offset;
    assert [memory.log + log_idx + 1] = value.low;
    assert [memory.log + log_idx + 2] = value.high;
    
    // Also update global dict for byte-level access (isolated by memory.log pointer)
    // Hint implemented in Rust - see hint_memory_store
    %{
        if '_memory_contexts' not in dir():
            global _memory_contexts
            _memory_contexts = {}
        
        mem_id = ids.memory.log
        if mem_id not in _memory_contexts:
            _memory_contexts[mem_id] = {}
        
        ctx_mem = _memory_contexts[mem_id]
        val = (ids.value.high << 128) | ids.value.low
        for i in range(32):
            ctx_mem[ids.offset + i] = (val >> (8 * (31 - i))) & 0xFF
    %}
    
    // Update cache - check if address exists
    let (cache_idx, found) = _find_in_cache(memory.cache, memory.cache_count, offset, 0);
    
    if (found == 1) {
        // Update existing cache entry - need new cache array
        let (new_cache) = alloc();
        _copy_cache_update(memory.cache, new_cache, memory.cache_count, 
                          cache_idx, value.low, value.high, 0);
        return (new_memory=Memory(
            log=memory.log, 
            log_count=memory.log_count + 1,
            cache=new_cache,
            cache_count=memory.cache_count
        ));
    }
    
    // Add new entry to cache
    let use_full_cache = is_le(CACHE_SIZE, memory.cache_count);
    if (use_full_cache == 1) {
        // Cache full - shift and add (evict oldest)
        let (new_cache) = alloc();
        _shift_cache_add(memory.cache, new_cache, memory.cache_count,
                        offset, value.low, value.high, 1);
        return (new_memory=Memory(
            log=memory.log,
            log_count=memory.log_count + 1,
            cache=new_cache,
            cache_count=CACHE_SIZE
        ));
    }
    
    // Add to end of cache
    let cidx = memory.cache_count * 3;
    assert [memory.cache + cidx] = offset;
    assert [memory.cache + cidx + 1] = value.low;
    assert [memory.cache + cidx + 2] = value.high;
    
    return (new_memory=Memory(
        log=memory.log,
        log_count=memory.log_count + 1,
        cache=memory.cache,
        cache_count=memory.cache_count + 1
    ));
}

// Store a byte
func memory_store_byte{range_check_ptr}(
    memory: Memory, offset: felt, value: felt
) -> (new_memory: Memory) {
    alloc_locals;
    // Update byte-level dict (isolated)
    // Hint implemented in Rust - see hint_memory_store8
    %{
        if '_memory_contexts' not in dir():
            global _memory_contexts
            _memory_contexts = {}
        
        mem_id = ids.memory.log
        if mem_id not in _memory_contexts:
            _memory_contexts[mem_id] = {}
            
        _memory_contexts[mem_id][ids.offset] = ids.value & 0xFF
    %}
    
    // We still append to log for consistency, but we mark it as a byte write if we wanted to.
    // For now, just store as a word with 1 byte (may cause issues with exact-match load, 
    // but the byte-level load will fix it)
    return memory_store(memory, offset, Uint256(low=value, high=0));
}

// Load a byte
func memory_load_byte{range_check_ptr}(memory: Memory, offset: felt) -> (value: felt) {
    alloc_locals;
    local val: felt;
    // Hint implemented in Rust - see hint_memory_load_byte (via HINT_MEMORY_LOAD_BYTES)
    %{
        if '_memory_contexts' not in dir():
            global _memory_contexts
            _memory_contexts = {}
        
        mem_id = ids.memory.log
        ctx_mem = _memory_contexts.get(mem_id, {})
        ids.val = ctx_mem.get(ids.offset, 0) & 0xFF
    %}
    return (value=val);
}

// Load a value - Byte-addressable via hints
func memory_load{range_check_ptr}(memory: Memory, offset: felt) -> (value: Uint256) {
    alloc_locals;
    local low: felt;
    local high: felt;
    // Hint implemented in Rust - see hint_memory_load
    %{
        if '_memory_contexts' not in dir():
            global _memory_contexts
            _memory_contexts = {}
        
        mem_id = ids.memory.log
        ctx_mem = _memory_contexts.get(mem_id, {})
        
        val = 0
        for i in range(32):
            val = (val << 8) | ctx_mem.get(ids.offset + i, 0)
        
        ids.low = val & ((1 << 128) - 1)
        ids.high = val >> 128
    %}
    return (value=Uint256(low=low, high=high));
}

// Find address in cache, returns (index, found)
func _find_in_cache(cache: felt*, count: felt, target: felt, i: felt) -> (idx: felt, found: felt) {
    if (i == count) {
        return (idx=0, found=0);
    }
    
    let cidx = i * 3;
    let addr = [cache + cidx];
    
    if (addr == target) {
        return (idx=i, found=1);
    }
    
    return _find_in_cache(cache, count, target, i + 1);
}

// Copy cache with one entry updated
func _copy_cache_update(
    src: felt*, dst: felt*, count: felt,
    update_idx: felt, new_low: felt, new_high: felt,
    i: felt
) {
    if (i == count) {
        return ();
    }
    
    let sidx = i * 3;
    let didx = i * 3;
    
    if (i == update_idx) {
        // Copy address, update value
        assert [dst + didx] = [src + sidx];
        assert [dst + didx + 1] = new_low;
        assert [dst + didx + 2] = new_high;
    } else {
        // Direct copy
        assert [dst + didx] = [src + sidx];
        assert [dst + didx + 1] = [src + sidx + 1];
        assert [dst + didx + 2] = [src + sidx + 2];
    }
    
    return _copy_cache_update(src, dst, count, update_idx, new_low, new_high, i + 1);
}

// Shift cache left, add new entry at end
func _shift_cache_add(
    src: felt*, dst: felt*, count: felt,
    new_addr: felt, new_low: felt, new_high: felt,
    i: felt  // src index, dst index = i-1
) {
    if (i == count) {
        // Add new entry at end
        let didx = (count - 1) * 3;
        assert [dst + didx] = new_addr;
        assert [dst + didx + 1] = new_low;
        assert [dst + didx + 2] = new_high;
        return ();
    }
    
    let sidx = i * 3;
    let didx = (i - 1) * 3;
    
    assert [dst + didx] = [src + sidx];
    assert [dst + didx + 1] = [src + sidx + 1];
    assert [dst + didx + 2] = [src + sidx + 2];
    
    return _shift_cache_add(src, dst, count, new_addr, new_low, new_high, i + 1);
}

// Scan log backwards for address
func _scan_log{range_check_ptr}(log: felt*, count: felt, target: felt) -> (value: Uint256) {
    if (count == 0) {
        return (value=Uint256(low=0, high=0));
    }
    
    let idx = (count - 1) * 3;
    let addr = [log + idx];
    
    if (addr == target) {
        let low = [log + idx + 1];
        let high = [log + idx + 2];
        return (value=Uint256(low=low, high=high));
    }
    
    return _scan_log(log, count - 1, target);
}

// Get memory size
func memory_size{range_check_ptr}(memory: Memory) -> (size: felt) {
    return _find_max_log(memory.log, memory.log_count, 0);
}

func _find_max_log{range_check_ptr}(log: felt*, count: felt, max_so_far: felt) -> (size: felt) {
    if (count == 0) {
        if (max_so_far == 0) {
            return (size=0);
        }
        return (size=max_so_far + 32);
    }
    
    let idx = (count - 1) * 3;
    let addr = [log + idx];
    
    let is_bigger = is_le(max_so_far + 1, addr);
    if (is_bigger == 1) {
        return _find_max_log(log, count - 1, addr);
    }
    return _find_max_log(log, count - 1, max_so_far);
}

// Reset memory to empty state
func memory_reset(memory: Memory) -> (new_memory: Memory) {
    let (new_log) = alloc();
    let (new_cache) = alloc();
    return (new_memory=Memory(log=new_log, log_count=0, cache=new_cache, cache_count=0));
}

// Copy bytes from src_memory to dst_memory
func memory_copy_bytes(
    src_memory: Memory, src_offset: felt,
    dst_memory: Memory, dst_offset: felt,
    length: felt
) -> (new_dst_memory: Memory) {
    if (length == 0) {
        return (new_dst_memory=dst_memory);
    }
    
    // Hint implemented in Rust - see hint_memory_copy_bytes
    %{
        src_id = ids.src_memory.log
        dst_id = ids.dst_memory.log
        src_ctx = _memory_contexts.get(src_id, {})
        if dst_id not in _memory_contexts:
            _memory_contexts[dst_id] = {}
        dst_ctx = _memory_contexts[dst_id]
        
        for i in range(ids.length):
            dst_ctx[ids.dst_offset + i] = src_ctx.get(ids.src_offset + i, 0)
    %}
    
    return (new_dst_memory=dst_memory);
}

// Load bytes to felt array (one byte per felt)
func memory_load_bytes_to_felt_array{range_check_ptr}(
    memory: Memory, offset: felt, length: felt, dst: felt*
) {
    if (length == 0) {
        return ();
    }
    // Hint implemented in Rust - see hint_memory_load_bytes
    %{
        offset = ids.offset
        length = ids.length
        
        if '_memory_contexts' not in dir():
            global _memory_contexts
            _memory_contexts = {}
            
        mem_id = ids.memory.log
        ctx_mem = _memory_contexts.get(mem_id, {})
        
        for i in range(length):
            memory[ids.dst + i] = ctx_mem.get(offset + i, 0)
    %}
    return ();
}

