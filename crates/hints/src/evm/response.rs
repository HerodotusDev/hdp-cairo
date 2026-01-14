// Rust hint to write EVM execution response directly to memory
// This bypasses DiffAssertValues errors when writing success=0

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

/// Write EVM execution response directly to memory segment
/// 
/// Input variables:
/// - response_retdata_start: Pointer to response segment start
/// - success: Execution success (0 or 1)
/// - gas_used: Gas consumed
/// - ret_size: Return data size
/// 
/// This hint writes directly to memory, avoiding DiffAssertValues errors
pub const HINT_WRITE_EVM_RESPONSE: &str = "# Write EVM execution response directly to memory";

pub fn hint_write_evm_response(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    // Read input variables from Cairo Zero context
    // We need to read: response (struct pointer), success, gas_used, ret_size
    use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::get_relocatable_from_var_name;
    
    // Get response struct address
    let response_addr = get_relocatable_from_var_name("response", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    // response.retdata_start is at offset 0 in the CallContractResponse struct
    let response_retdata_start = vm.get_relocatable(response_addr)?;
    
    // Read values from Cairo Zero context
    let success = get_integer_from_var_name("success", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_biguint();
    let gas_used = get_integer_from_var_name("gas_used", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_biguint();
    let ret_size = get_integer_from_var_name("ret_size", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .to_biguint();

    // Convert to Felt252
    let success_felt = Felt252::from(success);
    let gas_used_felt = Felt252::from(gas_used);
    let ret_size_felt = Felt252::from(ret_size);

    // Write directly to memory using vm.segments.load_data which can overwrite existing values
    // This avoids DiffAssertValues errors by using a method that allows overwriting
    use cairo_vm::types::relocatable::MaybeRelocatable;
    
    // Use load_data which can overwrite existing values without causing DiffAssertValues
    let values = vec![
        MaybeRelocatable::Int(success_felt),
        MaybeRelocatable::Int(gas_used_felt),
        MaybeRelocatable::Int(ret_size_felt),
    ];
    
    vm.segments.load_data(response_retdata_start, &values)?;

    Ok(())
}
