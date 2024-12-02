use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::{
    get_integer_from_var_name, insert_value_from_var_name,
};
use cairo_vm::types::exec_scope::ExecutionScopes;
use cairo_vm::types::relocatable::{MaybeRelocatable, Relocatable};
use cairo_vm::vm::{errors::hint_errors::HintError, vm_core::VirtualMachine};
use cairo_vm::Felt252;
use starknet_types_core::felt::NonZeroFelt;
use std::collections::HashMap;

pub const HINT_DIVMOD_VALUE: &str = "ids.q, ids.r = divmod(memory[ids.value + ids.i], ids.devisor)";

pub fn hint_divmod_value(
    vm: &mut VirtualMachine,
    _exec_scope: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let value: usize =
        get_integer_from_var_name("value", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
            .try_into()
            .unwrap();
    let i: usize = get_integer_from_var_name("i", vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();
    let devisor: Felt252 =
        get_integer_from_var_name("devisor", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let value: Felt252 = *vm.get_integer(Relocatable {
        segment_index: isize::default(),
        offset: value + i,
    })?;

    let (q, r) = value.div_rem(&NonZeroFelt::try_from(devisor).unwrap());
    insert_value_from_var_name(
        "q",
        MaybeRelocatable::Int(q),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;
    insert_value_from_var_name(
        "r",
        MaybeRelocatable::Int(r),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}
