use crate::{cairo_types::structs::BuiltinParams, hints::vars};
use cairo_vm::{
    hint_processor::{
        builtin_hint_processor::{
            builtin_hint_processor_definition::HintProcessorData,
            hint_utils::{
                get_integer_from_var_name, get_ptr_from_var_name, insert_value_from_var_name,
            },
        },
        hint_processor_utils::felt_to_usize,
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::{any::Any, collections::HashMap, ops::AddAssign};

pub const UPDATE_BUILTIN_PTRS: &str = "from starkware.starknet.core.os.os_utils import update_builtin_pointers\n\n# Fill the values of all builtin pointers after the current transaction.\nids.return_builtin_ptrs = segments.gen_arg(\n    update_builtin_pointers(\n        memory=memory,\n        n_builtins=ids.n_builtins,\n        builtins_encoding_addr=ids.builtin_params.builtin_encodings.address_,\n        n_selected_builtins=ids.n_selected_builtins,\n        selected_builtins_encoding_addr=ids.selected_encodings,\n        orig_builtin_ptrs_addr=ids.builtin_ptrs.selectable.address_,\n        selected_builtin_ptrs_addr=ids.selected_ptrs,\n        ),\n    )";

pub fn update_builtin_ptrs(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let n_builtins = get_integer_from_var_name(
        vars::ids::N_BUILTINS,
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    let builtin_params = get_ptr_from_var_name(
        vars::ids::BUILTIN_PARAMS,
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;
    let builtins_encoding_addr =
        vm.get_relocatable((builtin_params + BuiltinParams::builtin_encodings_offset())?)?;

    let n_selected_builtins = get_integer_from_var_name(
        vars::ids::N_SELECTED_BUILTINS,
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    let selected_encodings = get_ptr_from_var_name(
        vars::ids::SELECTED_ENCODINGS,
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    let builtin_ptrs = get_ptr_from_var_name(
        vars::ids::BUILTIN_PTRS,
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    let orig_builtin_ptrs = builtin_ptrs;

    let selected_ptrs = get_ptr_from_var_name(
        vars::ids::SELECTED_PTRS,
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    let all_builtins =
        vm.get_continuous_range(builtins_encoding_addr, felt_to_usize(&n_builtins)?)?;

    let selected_builtins =
        vm.get_continuous_range(selected_encodings, felt_to_usize(&n_selected_builtins)?)?;

    let mut returned_builtins: Vec<MaybeRelocatable> = Vec::new();
    let mut selected_builtin_offset: usize = 0;

    for (i, builtin) in all_builtins.iter().enumerate() {
        if selected_builtins.contains(builtin) {
            returned_builtins.push(
                vm.get_maybe(&(selected_ptrs + selected_builtin_offset)?)
                    .unwrap(),
            );
            selected_builtin_offset += 1;
        } else {
            returned_builtins.push(vm.get_maybe(&(orig_builtin_ptrs + i)?).unwrap());
        }
    }

    let return_builtin_ptrs_base = vm.add_memory_segment();
    vm.load_data(return_builtin_ptrs_base, &returned_builtins)?;

    insert_value_from_var_name(
        vars::ids::RETURN_BUILTIN_PTRS,
        return_builtin_ptrs_base,
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )
}

pub const SELECT_BUILTIN: &str = "# A builtin should be selected iff its encoding appears in the selected encodings list\n# and the list wasn't exhausted.\n# Note that testing inclusion by a single comparison is possible since the lists are sorted.\nids.select_builtin = int(\n  n_selected_builtins > 0 and memory[ids.selected_encodings] == memory[ids.all_encodings])\nif ids.select_builtin:\n  n_selected_builtins = n_selected_builtins - 1";

pub fn select_builtin(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let selected_encodings = get_ptr_from_var_name(
        vars::ids::SELECTED_ENCODINGS,
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    let all_encodings = get_ptr_from_var_name(
        vars::ids::ALL_ENCODINGS,
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    let n_selected_builtins =
        exec_scopes.get_mut_ref::<Felt252>(vars::scopes::N_SELECTED_BUILTINS)?;

    let select_builtin = *n_selected_builtins > Felt252::ZERO
        && vm.get_maybe(&selected_encodings).unwrap() == vm.get_maybe(&all_encodings).unwrap();

    insert_value_from_var_name(
        vars::ids::SELECT_BUILTIN,
        Felt252::from(select_builtin),
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?;

    if select_builtin {
        n_selected_builtins.add_assign(-Felt252::ONE);
    }

    Ok(())
}

pub const SELECTED_BUILTINS: &str =
    "vm_enter_scope({'n_selected_builtins': ids.n_selected_builtins})";

pub fn selected_builtins(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let n_selected_builtins: Box<dyn Any> = Box::new(get_integer_from_var_name(
        vars::ids::N_SELECTED_BUILTINS,
        vm,
        &hint_data.ids_data,
        &hint_data.ap_tracking,
    )?);
    exec_scopes.enter_scope(HashMap::from_iter([(
        String::from(vars::scopes::N_SELECTED_BUILTINS),
        n_selected_builtins,
    )]));

    Ok(())
}
