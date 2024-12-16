use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, get_ptr_from_var_name, insert_value_into_ap},
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;

use crate::{
    hint_processor::models::proofs::{header::Header, Proofs},
    hints::vars,
};

pub const HINT_BATCH_HEADERS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(batch.headers))";

pub fn hint_batch_headers_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let batch = exec_scopes.get::<Proofs>(vars::scopes::BATCH)?;

    insert_value_into_ap(vm, Felt252::from(batch.headers.len()))
}

pub const HINT_SET_HEADER: &str = "header = batch.headers[ids.idx - 1]\nsegments.write_arg(ids.rlp, [int(x, 16) for x in header.rlp])";

pub fn hint_set_header(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let batch = exec_scopes.get::<Proofs>(vars::scopes::BATCH)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();
    let header = batch.headers[idx - 1].clone();
    let rlp_le_chunks: Vec<Felt252> = header.rlp.chunks(8).map(Felt252::from_bytes_le_slice).collect();

    exec_scopes.insert_value::<Header>(vars::scopes::HEADER, header);

    let rlp_ptr = get_ptr_from_var_name(vars::ids::RLP, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    vm.write_arg(rlp_ptr, &rlp_le_chunks)?;

    Ok(())
}

pub const HINT_RLP_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(header.rlp))";

pub fn hint_rlp_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header = exec_scopes.get::<Header>(vars::scopes::HEADER)?;

    insert_value_into_ap(vm, Felt252::from(header.rlp.len()))
}

pub const HINT_LEAF_IDX: &str = "memory[ap] = to_felt_or_relocatable(len(header.proof.leaf_idx))";

pub fn hint_leaf_idx(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header = exec_scopes.get::<Header>(vars::scopes::HEADER)?;

    insert_value_into_ap(vm, Felt252::from(header.proof.leaf_idx))
}

pub const HINT_MMR_PATH_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(header.proof.mmr_path))";

pub fn hint_mmr_path_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header = exec_scopes.get::<Header>(vars::scopes::HEADER)?;

    insert_value_into_ap(vm, Felt252::from(header.proof.mmr_path.len()))
}

pub const HINT_MMR_PATH: &str = "segments.write_arg(ids.mmr_path, [int(x, 16) for x in header.proof.mmr_path])";

pub fn hint_mmr_path(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header = exec_scopes.get::<Header>(vars::scopes::HEADER)?;
    let mmr_path_ptr = get_ptr_from_var_name(vars::ids::MMR_PATH, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let mmr_path: Vec<Felt252> = header.proof.mmr_path.into_iter().map(|f| Felt252::from_bytes_be_slice(&f.0)).collect();

    vm.write_arg(mmr_path_ptr, &mmr_path)?;

    Ok(())
}
