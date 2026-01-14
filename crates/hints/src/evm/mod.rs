// EVM memory and storage hints for Cairo Zero EVM interpreter

pub mod bytecode;
pub mod debug;
pub mod push;
pub mod response;

use std::collections::HashMap;
use std::sync::Mutex;
use once_cell::sync::Lazy;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, get_ptr_from_var_name, get_relocatable_from_var_name, insert_value_from_var_name},
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use num_bigint::BigUint;
use num_traits::{ToPrimitive, Zero};

// Global state for EVM memory contexts (keyed by memory.log pointer)
static MEMORY_CONTEXTS: Lazy<Mutex<HashMap<usize, HashMap<usize, u8>>>> = 
    Lazy::new(|| Mutex::new(HashMap::new()));

// Global state for EVM storage (keyed by (address, key_low, key_high))
static EVM_STORAGE: Lazy<Mutex<HashMap<(u128, u128, u128), (u128, u128)>>> = 
    Lazy::new(|| Mutex::new(HashMap::new()));

// Global state for returndata
static RETURNDATA_STATE: Lazy<Mutex<ReturndataState>> = 
    Lazy::new(|| Mutex::new(ReturndataState::default()));

#[derive(Default)]
struct ReturndataState {
    return_offset: usize,
    return_size: usize,
    last_returndata: Vec<u8>,
}

// ============ MEMORY HINTS ============

pub const HINT_MEMORY_STORE: &str = r#"if '_memory_contexts' not in dir():
    global _memory_contexts
    _memory_contexts = {}

mem_id = ids.memory.log
if mem_id not in _memory_contexts:
    _memory_contexts[mem_id] = {}

ctx_mem = _memory_contexts[mem_id]
val = (ids.value.high << 128) | ids.value.low
for i in range(32):
    ctx_mem[ids.offset + i] = (val >> (8 * (31 - i))) & 0xFF"#;

pub fn hint_memory_store(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    // Memory struct: { log: felt*, log_count: felt, cache: felt*, cache_count: felt }
    // memory.log is a pointer at offset 0 - we use the pointer's segment_index as ID
    let memory_addr = get_relocatable_from_var_name("memory", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let log_ptr = vm.get_relocatable(memory_addr)?;
    let mem_id = log_ptr.segment_index as usize * 1000000 + log_ptr.offset;
    
    let offset = get_integer_from_var_name("offset", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    
    // Uint256 struct: { low: felt, high: felt }
    // Read two consecutive felts
    let value_addr = get_relocatable_from_var_name("value", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let value_parts = vm.get_continuous_range(value_addr, 2)?;
    let low = value_parts[0].get_int().ok_or_else(|| HintError::CustomHint("value.low is not an integer".into()))?.to_biguint();
    let high = value_parts[1].get_int().ok_or_else(|| HintError::CustomHint("value.high is not an integer".into()))?.to_biguint();
    
    let val = (&high << 128u32) | &low;
    
    let mut contexts = MEMORY_CONTEXTS.lock().unwrap();
    let ctx_mem = contexts.entry(mem_id).or_insert_with(HashMap::new);
    
    for i in 0..32usize {
        let byte = ((&val >> (8 * (31 - i))) & BigUint::from(0xFFu8)).to_u8().unwrap_or(0);
        ctx_mem.insert(offset + i, byte);
    }
    
    Ok(())
}

pub const HINT_MEMORY_STORE8: &str = r#"if '_memory_contexts' not in dir():
    global _memory_contexts
    _memory_contexts = {}

mem_id = ids.memory.log
if mem_id not in _memory_contexts:
    _memory_contexts[mem_id] = {}
    
_memory_contexts[mem_id][ids.offset] = ids.value & 0xFF"#;

pub fn hint_memory_store8(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let memory_addr = get_relocatable_from_var_name("memory", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let log_ptr = vm.get_relocatable(memory_addr)?;
    let mem_id = log_ptr.segment_index as usize * 1000000 + log_ptr.offset;
    
    let offset = get_integer_from_var_name("offset", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    let value = get_integer_from_var_name("value", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_u8().unwrap_or(0);
    
    let mut contexts = MEMORY_CONTEXTS.lock().unwrap();
    let ctx_mem = contexts.entry(mem_id).or_insert_with(HashMap::new);
    ctx_mem.insert(offset, value);
    
    Ok(())
}

pub const HINT_MEMORY_LOAD: &str = r#"if '_memory_contexts' not in dir():
    global _memory_contexts
    _memory_contexts = {}

mem_id = ids.memory.log
ctx_mem = _memory_contexts.get(mem_id, {})

val = 0
for i in range(32):
    val = (val << 8) | ctx_mem.get(ids.offset + i, 0)

ids.low = val & ((1 << 128) - 1)
ids.high = val >> 128"#;

pub fn hint_memory_load(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let memory_addr = get_relocatable_from_var_name("memory", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let log_ptr = vm.get_relocatable(memory_addr)?;
    let mem_id = log_ptr.segment_index as usize * 1000000 + log_ptr.offset;
    
    let offset = get_integer_from_var_name("offset", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    
    let contexts = MEMORY_CONTEXTS.lock().unwrap();
    let ctx_mem = contexts.get(&mem_id);
    
    let mut val = BigUint::zero();
    for i in 0..32usize {
        let byte = ctx_mem
            .and_then(|m| m.get(&(offset + i)))
            .copied()
            .unwrap_or(0);
        val = (val << 8u32) | BigUint::from(byte);
    }
    
    let mask = (BigUint::from(1u128) << 128u32) - 1u32;
    let low = &val & &mask;
    let high = &val >> 128u32;
    
    insert_value_from_var_name("low", MaybeRelocatable::Int(Felt252::from(low)), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_from_var_name("high", MaybeRelocatable::Int(Felt252::from(high)), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    
    Ok(())
}

pub const HINT_MEMORY_COPY_BYTES: &str = r#"src_id = ids.src_memory.log
dst_id = ids.dst_memory.log
src_ctx = _memory_contexts.get(src_id, {})
if dst_id not in _memory_contexts:
    _memory_contexts[dst_id] = {}
dst_ctx = _memory_contexts[dst_id]

for i in range(ids.length):
    dst_ctx[ids.dst_offset + i] = src_ctx.get(ids.src_offset + i, 0)"#;

pub fn hint_memory_copy_bytes(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let src_memory_addr = get_relocatable_from_var_name("src_memory", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let src_log_ptr = vm.get_relocatable(src_memory_addr)?;
    let src_id = src_log_ptr.segment_index as usize * 1000000 + src_log_ptr.offset;
    let dst_memory_addr = get_relocatable_from_var_name("dst_memory", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let dst_log_ptr = vm.get_relocatable(dst_memory_addr)?;
    let dst_id = dst_log_ptr.segment_index as usize * 1000000 + dst_log_ptr.offset;
    
    let src_offset = get_integer_from_var_name("src_offset", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    let dst_offset = get_integer_from_var_name("dst_offset", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    let length = get_integer_from_var_name("length", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    
    let mut contexts = MEMORY_CONTEXTS.lock().unwrap();
    
    // Collect bytes from src first
    let bytes: Vec<u8> = (0..length)
        .map(|i| {
            contexts.get(&src_id)
                .and_then(|m| m.get(&(src_offset + i)))
                .copied()
                .unwrap_or(0)
        })
        .collect();
    
    // Then write to dst
    let dst_ctx = contexts.entry(dst_id).or_insert_with(HashMap::new);
    for (i, byte) in bytes.into_iter().enumerate() {
        dst_ctx.insert(dst_offset + i, byte);
    }
    
    Ok(())
}

pub const HINT_MEMORY_LOAD_BYTES: &str = r#"offset = ids.offset
length = ids.length

if '_memory_contexts' not in dir():
    global _memory_contexts
    _memory_contexts = {}
    
mem_id = ids.memory.log
ctx_mem = _memory_contexts.get(mem_id, {})

for i in range(length):
    memory[ids.dst + i] = ctx_mem.get(offset + i, 0)"#;

pub fn hint_memory_load_bytes(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let memory_addr = get_relocatable_from_var_name("memory", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let log_ptr = vm.get_relocatable(memory_addr)?;
    let mem_id = log_ptr.segment_index as usize * 1000000 + log_ptr.offset;
    
    let offset = get_integer_from_var_name("offset", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    let length = get_integer_from_var_name("length", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    let dst = get_ptr_from_var_name("dst", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    
    let contexts = MEMORY_CONTEXTS.lock().unwrap();
    let ctx_mem = contexts.get(&mem_id);
    
    for i in 0..length {
        let byte = ctx_mem
            .and_then(|m| m.get(&(offset + i)))
            .copied()
            .unwrap_or(0);
        vm.insert_value((dst + i)?, Felt252::from(byte))?;
    }
    
    Ok(())
}

// ============ STORAGE HINTS ============

pub const HINT_STORAGE_LOAD: &str = r#"if '_evm_storage' not in globals():
    global _evm_storage
    _evm_storage = {}

key = (ids.address, ids.key_low, ids.key_high)
if key in _evm_storage:
    val = _evm_storage[key]
    ids.value_low = val[0]
    ids.value_high = val[1]
else:
    ids.value_low = 0
    ids.value_high = 0"#;

pub fn hint_storage_load(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let address = get_integer_from_var_name("address", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_u128().unwrap_or(0);
    let key_low = get_integer_from_var_name("key_low", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_u128().unwrap_or(0);
    let key_high = get_integer_from_var_name("key_high", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_u128().unwrap_or(0);
    
    let storage = EVM_STORAGE.lock().unwrap();
    let (value_low, value_high) = storage.get(&(address, key_low, key_high))
        .copied()
        .unwrap_or((0, 0));
    
    insert_value_from_var_name("value_low", MaybeRelocatable::Int(Felt252::from(value_low)), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_from_var_name("value_high", MaybeRelocatable::Int(Felt252::from(value_high)), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    
    Ok(())
}

pub const HINT_STORAGE_STORE: &str = r#"if '_evm_storage' not in globals():
    global _evm_storage
    _evm_storage = {}
key = (ids.address, ids.key_low, ids.key_high)
_evm_storage[key] = (ids.value_low, ids.value_high)"#;

pub fn hint_storage_store(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let address = get_integer_from_var_name("address", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_u128().unwrap_or(0);
    let key_low = get_integer_from_var_name("key_low", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_u128().unwrap_or(0);
    let key_high = get_integer_from_var_name("key_high", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_u128().unwrap_or(0);
    let value_low = get_integer_from_var_name("value_low", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_u128().unwrap_or(0);
    let value_high = get_integer_from_var_name("value_high", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_u128().unwrap_or(0);
    
    let mut storage = EVM_STORAGE.lock().unwrap();
    storage.insert((address, key_low, key_high), (value_low, value_high));
    
    Ok(())
}

pub const HINT_STORAGE_RESET: &str = r#"if '_evm_storage' not in globals():
    global _evm_storage
    _evm_storage = {}
_evm_storage = {}

if '_memory_contexts' not in globals():
    global _memory_contexts
    _memory_contexts = {}
    
_memory_contexts['__return_offset'] = 0
_memory_contexts['__return_size'] = 0
_memory_contexts['__last_returndata'] = []"#;

pub fn hint_storage_reset(
    _vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    EVM_STORAGE.lock().unwrap().clear();
    MEMORY_CONTEXTS.lock().unwrap().clear();
    *RETURNDATA_STATE.lock().unwrap() = ReturndataState::default();
    Ok(())
}

pub const HINT_STORAGE_SET_RETURNDATA_SIZE: &str = r#"if '_memory_contexts' not in globals():
    global _memory_contexts
    _memory_contexts = {}
_memory_contexts['__return_size'] = ids.size"#;

pub fn hint_storage_set_returndata_size(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let size = get_integer_from_var_name("size", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    RETURNDATA_STATE.lock().unwrap().return_size = size;
    Ok(())
}

pub const HINT_STORAGE_GET_RETURNDATA_SIZE: &str = r#"if '_memory_contexts' not in globals():
    global _memory_contexts
    _memory_contexts = {}
ids.size = _memory_contexts.get('__return_size', 0)"#;

pub fn hint_storage_get_returndata_size(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let size = RETURNDATA_STATE.lock().unwrap().return_size;
    insert_value_from_var_name("size", MaybeRelocatable::Int(Felt252::from(size)), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    Ok(())
}

pub const HINT_STORAGE_SET_RETURN_DATA: &str = r#"if '_memory_contexts' not in globals():
    global _memory_contexts
    _memory_contexts = {}
_memory_contexts['__return_offset'] = ids.offset
_memory_contexts['__return_size'] = ids.size"#;

pub fn hint_storage_set_return_data(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let offset = get_integer_from_var_name("offset", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    let size = get_integer_from_var_name("size", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    
    let mut state = RETURNDATA_STATE.lock().unwrap();
    state.return_offset = offset;
    state.return_size = size;
    Ok(())
}

pub const HINT_STORAGE_GET_RETURN_OFFSET: &str = r#"if '_memory_contexts' not in globals():
    global _memory_contexts
    _memory_contexts = {}
ids.offset = _memory_contexts.get('__return_offset', 0)"#;

pub fn hint_storage_get_return_offset(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let offset = RETURNDATA_STATE.lock().unwrap().return_offset;
    insert_value_from_var_name("offset", MaybeRelocatable::Int(Felt252::from(offset)), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    Ok(())
}

pub const HINT_STORAGE_GET_RETURN_SIZE: &str = r#"if '_memory_contexts' not in globals():
    global _memory_contexts
    _memory_contexts = {}
ids.size = _memory_contexts.get('__return_size', 0)"#;

pub fn hint_storage_get_return_size(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let size = RETURNDATA_STATE.lock().unwrap().return_size;
    insert_value_from_var_name("size", MaybeRelocatable::Int(Felt252::from(size)), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    Ok(())
}

pub const HINT_STORAGE_SET_RETURNDATA: &str = r#"if '_memory_contexts' not in globals():
    global _memory_contexts
    _memory_contexts = {}

child_mem_id = ids.child_memory.log
child_ctx_mem = _memory_contexts.get(child_mem_id, {})

last_ret = []
for i in range(ids.size):
    last_ret.append(child_ctx_mem.get(ids.offset + i, 0))
    
_memory_contexts['__last_returndata'] = last_ret
_memory_contexts['__return_size'] = ids.size"#;

pub fn hint_storage_set_returndata(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let child_memory_addr = get_relocatable_from_var_name("child_memory", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let child_log_ptr = vm.get_relocatable(child_memory_addr)?;
    let child_mem_id = child_log_ptr.segment_index as usize * 1000000 + child_log_ptr.offset;
    
    let offset = get_integer_from_var_name("offset", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    let size = get_integer_from_var_name("size", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    
    let contexts = MEMORY_CONTEXTS.lock().unwrap();
    let child_ctx_mem = contexts.get(&child_mem_id);
    
    let last_ret: Vec<u8> = (0..size)
        .map(|i| {
            child_ctx_mem
                .and_then(|m| m.get(&(offset + i)))
                .copied()
                .unwrap_or(0)
        })
        .collect();
    
    drop(contexts);
    
    let mut state = RETURNDATA_STATE.lock().unwrap();
    state.last_returndata = last_ret;
    state.return_size = size;
    
    Ok(())
}

// ============ INTERPRETER HINTS ============

pub const HINT_ADDRESS: &str = r#"ids.low = ids.ctx.contract_address & ((1 << 128) - 1)
ids.high = ids.ctx.contract_address >> 128"#;

pub fn hint_address(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let ctx_ptr = get_ptr_from_var_name("ctx", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    // contract_address is at offset 3 in ExecutionContext struct
    let contract_address = vm.get_integer((ctx_ptr + 3)?)?.to_biguint();
    
    let mask = (BigUint::from(1u128) << 128u32) - 1u32;
    let low = &contract_address & &mask;
    let high = &contract_address >> 128u32;
    
    insert_value_from_var_name("low", MaybeRelocatable::Int(Felt252::from(low)), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_from_var_name("high", MaybeRelocatable::Int(Felt252::from(high)), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    
    Ok(())
}

pub const HINT_CALLER: &str = r#"ids.low = ids.ctx.caller & ((1 << 128) - 1)
ids.high = ids.ctx.caller >> 128"#;

pub fn hint_caller(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let ctx_ptr = get_ptr_from_var_name("ctx", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    // caller is at offset 4 in ExecutionContext struct
    let caller = vm.get_integer((ctx_ptr + 4)?)?.to_biguint();
    
    let mask = (BigUint::from(1u128) << 128u32) - 1u32;
    let low = &caller & &mask;
    let high = &caller >> 128u32;
    
    insert_value_from_var_name("low", MaybeRelocatable::Int(Felt252::from(low)), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_from_var_name("high", MaybeRelocatable::Int(Felt252::from(high)), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    
    Ok(())
}

pub const HINT_RETURNDATACOPY: &str = r#" if '_memory_contexts' not in globals():
     global _memory_contexts
     _memory_contexts = {}
 returndata = _memory_contexts.get('__last_returndata', [])
 dest = ids.rd_destOffset
 offset = ids.rd_offset
 length = ids.rd_length
 
 mem_id = ids.memory.log
 if mem_id not in _memory_contexts:
     _memory_contexts[mem_id] = {}
 ctx_mem = _memory_contexts[mem_id]
 
 for i in range(length):
     val = 0
     if offset + i < len(returndata):
         val = returndata[offset + i]
     ctx_mem[dest + i] = val"#;

pub fn hint_returndatacopy(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let memory_addr = get_relocatable_from_var_name("memory", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let log_ptr = vm.get_relocatable(memory_addr)?;
    let mem_id = log_ptr.segment_index as usize * 1000000 + log_ptr.offset;
    
    let rd_dest_offset = get_integer_from_var_name("rd_destOffset", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    let rd_offset = get_integer_from_var_name("rd_offset", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    let rd_length = get_integer_from_var_name("rd_length", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    
    let returndata = RETURNDATA_STATE.lock().unwrap().last_returndata.clone();
    
    let mut contexts = MEMORY_CONTEXTS.lock().unwrap();
    let ctx_mem = contexts.entry(mem_id).or_insert_with(HashMap::new);
    
    for i in 0..rd_length {
        let val = if rd_offset + i < returndata.len() {
            returndata[rd_offset + i]
        } else {
            0
        };
        ctx_mem.insert(rd_dest_offset + i, val);
    }
    
    Ok(())
}

// SHA3/KECCAK256 hint - computes keccak hash of memory region
pub const HINT_SHA3: &str = r#"# Read from isolated memory context
if '_memory_contexts' not in dir():
    global _memory_contexts
    _memory_contexts = {}

mem_id = ids.memory.log
ctx_mem = _memory_contexts.get(mem_id, {})

offset_val = ids.offset.low
size_val = ids.size.low

data_bytes = []
for i in range(size_val):
    data_bytes.append(ctx_mem.get(offset_val + i, 0))

# Compute keccak256 hash"#;

pub fn hint_sha3(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    use sha3::{Keccak256, Digest};
    
    let memory_addr = get_relocatable_from_var_name("memory", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let log_ptr = vm.get_relocatable(memory_addr)?;
    let mem_id = log_ptr.segment_index as usize * 1000000 + log_ptr.offset;
    
    // offset and size are Uint256 structs: { low: felt, high: felt }
    let offset_addr = get_relocatable_from_var_name("offset", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let offset_val = vm.get_integer(offset_addr)?.to_usize().unwrap_or(0); // .low
    let size_addr = get_relocatable_from_var_name("size", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let size_val = vm.get_integer(size_addr)?.to_usize().unwrap_or(0); // .low
    
    let contexts = MEMORY_CONTEXTS.lock().unwrap();
    let ctx_mem = contexts.get(&mem_id);
    
    let data_bytes: Vec<u8> = (0..size_val)
        .map(|i| {
            ctx_mem
                .and_then(|m| m.get(&(offset_val + i)))
                .copied()
                .unwrap_or(0)
        })
        .collect();
    
    // Compute keccak256 hash
    let mut hasher = Keccak256::new();
    hasher.update(&data_bytes);
    let hash = hasher.finalize();
    
    // Split into high (first 16 bytes) and low (last 16 bytes)
    let high = BigUint::from_bytes_be(&hash[0..16]);
    let low = BigUint::from_bytes_be(&hash[16..32]);
    
    insert_value_from_var_name("hash_low", MaybeRelocatable::Int(Felt252::from(low)), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_from_var_name("hash_high", MaybeRelocatable::Int(Felt252::from(high)), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    
    Ok(())
}

pub const HINT_EXTRACT_WORD_FROM_BYTECODE: &str = r#"# Extract 32 bytes from bytecode array starting at offset
# Bytecode is an array of felts (one per byte)
bytecode = [getattr(ids, 'bytecode')[i] for i in range(ids.bytecode_len)]

word_bytes = []
for i in range(32):
    idx = ids.offset + i
    if idx < ids.bytecode_len:
        word_bytes.append(bytecode[idx])
    else:
        word_bytes.append(0)

# Convert to Uint256
ids.high = int.from_bytes(word_bytes[:16], 'big')
ids.low = int.from_bytes(word_bytes[16:], 'big')"#;

pub fn hint_extract_word_from_bytecode(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let bytecode = get_ptr_from_var_name("bytecode", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let bytecode_len = get_integer_from_var_name("bytecode_len", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    let offset = get_integer_from_var_name("offset", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_usize().unwrap_or(0);
    
    let mut word_bytes = Vec::with_capacity(32);
    for i in 0..32 {
        let idx = offset + i;
        let byte = if idx < bytecode_len {
            vm.get_integer((bytecode + idx)?)?.to_u8().unwrap_or(0)
        } else {
            0
        };
        word_bytes.push(byte);
    }
    
    // Convert to Uint256
    let high = BigUint::from_bytes_be(&word_bytes[0..16]);
    let low = BigUint::from_bytes_be(&word_bytes[16..32]);
    
    insert_value_from_var_name("high", MaybeRelocatable::Int(Felt252::from(high)), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    insert_value_from_var_name("low", MaybeRelocatable::Int(Felt252::from(low)), vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    
    Ok(())
}

