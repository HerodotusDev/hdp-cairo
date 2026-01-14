// EVM debug logging hints for sound-run

use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, get_ptr_from_var_name},
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use num_traits::ToPrimitive;

pub const HINT_DEBUG_BYTECODE_LOADED: &str = r#"# Debug: Log bytecode loading result
# This hint is called after load_bytecode to check if bytecode was found
ids.debug_bytecode_len = ids.bytecode_len"#;

pub fn hint_debug_bytecode_loaded(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let bytecode_len = get_integer_from_var_name("bytecode_len", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    
    eprintln!("[DEBUG load_bytecode] bytecode_len={}", bytecode_len);
    
    if bytecode_len == Felt252::ZERO {
        eprintln!("[ERROR load_bytecode] Bytecode not found in evm_memorizer! Key mismatch or bytecode not stored.");
    } else {
        eprintln!("[DEBUG load_bytecode] Bytecode found, length={} bytes", bytecode_len);
        
        // Try to read first byte of bytecode if available
        if let Ok(bytecode_ptr) = get_ptr_from_var_name("bytecode", vm, &hint_data.ids_data, &hint_data.ap_tracking) {
            if let Ok(first_byte) = vm.get_integer(bytecode_ptr) {
                eprintln!("[DEBUG load_bytecode] First bytecode byte: 0x{:02x}", first_byte.to_u64().unwrap_or(0));
            }
        }
    }
    
    Ok(())
}

pub const HINT_DEBUG_EVM_EXECUTION: &str = r#"# Debug: Log EVM execution result
# This hint is called after execute_loop to check execution status
ids.debug_success = ids.success
ids.debug_final_pc = ids.final_pc"#;

pub fn hint_debug_evm_execution(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let success = get_integer_from_var_name("success", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let final_pc = get_integer_from_var_name("final_pc", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    
    eprintln!("[DEBUG execute_loop] Execution completed: success={}, final_pc={}", success, final_pc);
    
    if success == Felt252::ZERO {
        eprintln!("[ERROR execute_loop] EVM execution failed! final_pc={}", final_pc);
        
        // Try to get more context if available
        if let Ok(bytecode_len) = get_integer_from_var_name("bytecode_len", vm, &hint_data.ids_data, &hint_data.ap_tracking) {
            eprintln!("[ERROR execute_loop] bytecode_len={}", bytecode_len);
        }
        if let Ok(gas) = get_integer_from_var_name("gas", vm, &hint_data.ids_data, &hint_data.ap_tracking) {
            eprintln!("[ERROR execute_loop] Remaining gas={}", gas);
        }
    } else {
        eprintln!("[DEBUG execute_loop] EVM execution succeeded! final_pc={}", final_pc);
    }
    
    Ok(())
}

pub const HINT_DEBUG_RETURN_DATA: &str = r#"# Debug: Log return data details
# This hint is called before writing return data
ids.debug_ret_size = ids.ret_size
ids.debug_ret_off = ids.ret_off"#;

pub fn hint_debug_return_data(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let ret_size = get_integer_from_var_name("ret_size", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let ret_off = get_integer_from_var_name("ret_off", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    
    eprintln!("[DEBUG return_data] ret_offset={}, ret_size={}", ret_off, ret_size);
    
    if ret_size == Felt252::ZERO {
        eprintln!("[WARNING return_data] No return data! EVM execution may have failed or returned empty data.");
    }
    
    Ok(())
}

pub const HINT_DEBUG_OPCODE_EXECUTION: &str = r#"# Debug: Log opcode execution details
# This hint is called at the start of each opcode execution
ids.debug_pc = ids.pc
ids.debug_opcode = ids.opcode
ids.debug_gas = ids.gas"#;

pub fn hint_debug_opcode_execution(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    use num_bigint::BigUint;
    
    let pc = get_integer_from_var_name("pc", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let opcode = get_integer_from_var_name("opcode", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let gas = get_integer_from_var_name("gas", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    
    let pc_val = pc.to_biguint();
    let opcode_val = opcode.to_biguint();
    let gas_val = gas.to_biguint();
    
    let opcode_hex = opcode_val.to_u64().map(|v| format!("0x{:02x}", v)).unwrap_or_else(|| "?".to_string());
    
    eprintln!("[DEBUG opcode] PC={}, Opcode={}, Gas={}", 
             pc_val, opcode_hex, gas_val);
    
    Ok(())
}

pub const HINT_DEBUG_OPCODE_RESULT: &str = r#"# Debug: Log opcode execution result
# This hint is called after opcode execution
ids.debug_new_pc = ids.new_pc
ids.debug_new_gas = ids.new_gas
ids.debug_stopped = ids.stopped
ids.debug_success = ids.success"#;

pub fn hint_debug_opcode_result(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    use num_bigint::BigUint;
    use num_traits::Zero;
    
    let new_pc = get_integer_from_var_name("new_pc", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let new_gas = get_integer_from_var_name("new_gas", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let stopped = get_integer_from_var_name("stopped", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let success = get_integer_from_var_name("success", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    
    let new_pc_val = new_pc.to_biguint();
    let new_gas_val = new_gas.to_biguint();
    let stopped_val = stopped.to_biguint();
    let success_val = success.to_biguint();
    
    eprintln!("[DEBUG opcode_result] new_pc={}, new_gas={}, stopped={}, success={}", 
             new_pc_val, new_gas_val, stopped_val, success_val);
    
    if success_val == BigUint::zero() {
        eprintln!("[ERROR opcode_result] Opcode execution failed!");
    }
    
    Ok(())
}

pub const HINT_DEBUG_JUMPI: &str = r#"# Debug: Log JUMPI execution details
ids.debug_jumpi_cond = ids.cond.low
ids.debug_jumpi_dest = ids.dest.low
ids.debug_jumpi_bytecode_len = ids.bytecode_len"#;

pub fn hint_debug_jumpi(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    use num_bigint::BigUint;
    use num_traits::ToPrimitive;
    
    let bytecode_len = get_integer_from_var_name("bytecode_len", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    
    // Get cond.low and dest.low - these are Uint256 structs accessed via debug variables
    let cond_low = get_integer_from_var_name("debug_jumpi_cond", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let dest_low = get_integer_from_var_name("debug_jumpi_dest", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    
    let cond_low_val = cond_low.to_biguint();
    let dest_low_val = dest_low.to_biguint();
    let bytecode_len_val = bytecode_len.to_biguint();
    
    eprintln!("[DEBUG JUMPI] cond={}, dest={}, bytecode_len={}", 
             cond_low_val, dest_low_val, bytecode_len_val);
    
    // Check if destination is valid
    let dest_val = dest_low_val.to_usize().unwrap_or(0);
    let bytecode_len_val_usize = bytecode_len_val.to_usize().unwrap_or(0);
    
    if dest_val >= bytecode_len_val_usize {
        eprintln!("[ERROR JUMPI] Destination {} is out of bounds (bytecode_len={})", dest_val, bytecode_len_val_usize);
    } else {
        // Try to read the destination opcode
        if let Ok(bytecode_ptr) = get_ptr_from_var_name("bytecode", vm, &hint_data.ids_data, &hint_data.ap_tracking) {
            if let Ok(dest_opcode) = vm.get_integer((bytecode_ptr + dest_val)?) {
                let dest_op = dest_opcode.to_biguint().to_u64().unwrap_or(0);
                eprintln!("[DEBUG JUMPI] Destination opcode at PC={}: 0x{:02x}", dest_val, dest_op);
                if dest_op != 0x5B {
                    eprintln!("[ERROR JUMPI] Destination does not have JUMPDEST (0x5B), found 0x{:02x}", dest_op);
                }
            }
        }
    }
    
    Ok(())
}

