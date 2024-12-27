use crate::vars;
use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        dict_manager::DictManager,
        hint_utils::{get_integer_from_var_name, get_ptr_from_var_name, insert_value_into_ap},
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::{any::Any, cell::RefCell, collections::HashMap, rc::Rc};
use types::proofs::{header::Header, HeaderMmrMeta, Proofs};

pub const HINT_VM_ENTER_SCOPE: &str = "vm_enter_scope({'header_with_mmr': batch.headers_with_mmr[ids.idx - 1], '__dict_manager': __dict_manager})";

pub fn hint_vm_enter_scope(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proofs = exec_scopes.get::<Proofs>(vars::scopes::BATCH)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();

    let headers_with_mmr: Box<dyn Any> = Box::new(proofs.headers_with_mmr[idx - 1].clone());
    let dict_manager: Box<dyn Any> = Box::new(exec_scopes.get::<Rc<RefCell<DictManager>>>(vars::scopes::DICT_MANAGER)?);
    exec_scopes.enter_scope(HashMap::from([
        (String::from(vars::scopes::HEADER_WITH_MMR), headers_with_mmr),
        (String::from(vars::scopes::DICT_MANAGER), dict_manager),
    ]));

    Ok(())
}

pub const HINT_HEADERS_WITH_MMR_HEADERS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(header_with_mmr.headers))";

pub fn hint_headers_with_mmr_headers_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header_with_mmr = exec_scopes.get::<HeaderMmrMeta>(vars::scopes::HEADER_WITH_MMR)?;

    insert_value_into_ap(vm, Felt252::from(header_with_mmr.headers.len()))
}

pub const HINT_SET_HEADER: &str = "header = header_with_mmr.headers[ids.idx - 1]\nsegments.write_arg(ids.rlp, [int(x, 16) for x in header.rlp])";

pub fn hint_set_header(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let headers_with_mmr = exec_scopes.get::<HeaderMmrMeta>(vars::scopes::HEADER_WITH_MMR)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();

    let header = headers_with_mmr.headers[idx - 1].clone();
    let rlp_le_chunks: Vec<MaybeRelocatable> = header
        .rlp
        .chunks(8)
        .map(|chunk| MaybeRelocatable::from(Felt252::from_bytes_be_slice(&chunk.iter().rev().copied().collect::<Vec<_>>())))
        .collect();

    exec_scopes.insert_value::<Header>(vars::scopes::HEADER, header);

    let rlp_ptr = get_ptr_from_var_name(vars::ids::RLP, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    vm.load_data(rlp_ptr, &rlp_le_chunks)?;

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

    insert_value_into_ap(vm, Felt252::from(header.rlp.chunks(8).count()))
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
    let mmr_path: Vec<MaybeRelocatable> = header
        .proof
        .mmr_path
        .into_iter()
        .map(|f| Felt252::from_bytes_be_slice(&f))
        .map(MaybeRelocatable::from)
        .collect();

    vm.load_data(mmr_path_ptr, &mmr_path)?;

    Ok(())
}
