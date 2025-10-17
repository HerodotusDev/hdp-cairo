use std::{any::Any, cell::RefCell, collections::HashMap, rc::Rc};

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
use types::proofs::{header::HeaderMmrMeta, starknet};

use crate::vars;

pub const HINT_HEADERS_WITH_MMR_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(batch_starknet.headers_with_mmr))";

pub fn hint_headers_with_mmr_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proofs = exec_scopes.get::<starknet::Proofs>(vars::scopes::BATCH_STARKNET)?;

    insert_value_into_ap(vm, Felt252::from(proofs.headers_with_mmr.len()))
}

pub const HINT_VM_ENTER_SCOPE: &str =
    "vm_enter_scope({'header_with_mmr_starknet': batch_starknet.headers_with_mmr[ids.idx - 1], '__dict_manager': __dict_manager})";

pub fn hint_vm_enter_scope(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proofs = exec_scopes.get::<starknet::Proofs>(vars::scopes::BATCH_STARKNET)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();

    let headers_with_mmr: Box<dyn Any> = Box::new(proofs.headers_with_mmr[idx - 1].clone());
    let dict_manager: Box<dyn Any> = Box::new(exec_scopes.get::<Rc<RefCell<DictManager>>>(vars::scopes::DICT_MANAGER)?);
    exec_scopes.enter_scope(HashMap::from([
        (String::from(vars::scopes::HEADER_WITH_MMR_STARKNET), headers_with_mmr),
        (String::from(vars::scopes::DICT_MANAGER), dict_manager),
    ]));

    Ok(())
}

pub const HINT_HEADERS_WITH_MMR_HEADERS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(header_with_mmr_starknet.headers))";

pub fn hint_headers_with_mmr_headers_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header_with_mmr = exec_scopes.get::<HeaderMmrMeta<starknet::header::Header>>(vars::scopes::HEADER_WITH_MMR_STARKNET)?;

    insert_value_into_ap(vm, Felt252::from(header_with_mmr.headers.len()))
}

pub const HINT_SET_HEADER: &str =
    "header_starknet = header_with_mmr_starknet.headers[ids.idx - 1]\nsegments.write_arg(ids.fields, [int(x, 16) for x in header_starknet.fields])";

pub fn hint_set_header(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let headers_with_mmr = exec_scopes.get::<HeaderMmrMeta<starknet::header::Header>>(vars::scopes::HEADER_WITH_MMR_STARKNET)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();

    let header = headers_with_mmr.headers[idx - 1].clone();

    exec_scopes.insert_value::<starknet::header::Header>(vars::scopes::HEADER_STARKNET, header.clone());

    let fields_ptr = get_ptr_from_var_name(vars::ids::FIELDS, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    vm.load_data(
        fields_ptr,
        &header
            .fields
            .into_iter()
            .map(MaybeRelocatable::from)
            .collect::<Vec<MaybeRelocatable>>(),
    )?;

    Ok(())
}

pub const HINT_FIELDS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(header_starknet.fields))";

pub fn hint_rlp_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header = exec_scopes.get::<starknet::header::Header>(vars::scopes::HEADER_STARKNET)?;

    insert_value_into_ap(vm, Felt252::from(header.fields.len()))
}

pub const HINT_LEAF_IDX: &str = "memory[ap] = to_felt_or_relocatable(len(header_starknet.proof.leaf_idx))";

pub fn hint_leaf_idx(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header = exec_scopes.get::<starknet::header::Header>(vars::scopes::HEADER_STARKNET)?;

    insert_value_into_ap(vm, Felt252::from(header.proof.leaf_idx))
}

pub const HINT_MMR_PATH_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(header_starknet.proof.mmr_path))";

pub fn hint_mmr_path_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header = exec_scopes.get::<starknet::header::Header>(vars::scopes::HEADER_STARKNET)?;

    insert_value_into_ap(vm, Felt252::from(header.proof.mmr_path.len()))
}

pub const HINT_MMR_PATH: &str = "segments.write_arg(ids.mmr_path, [int(x, 16) for x in header_starknet.proof.mmr_path])";

pub fn hint_mmr_path(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header = exec_scopes.get::<starknet::header::Header>(vars::scopes::HEADER_STARKNET)?;
    let mmr_path_ptr = get_ptr_from_var_name(vars::ids::MMR_PATH, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    // Convert each Bytes element into a single felt (big-endian) as expected by
    // packages/eth_essentials/lib/mmr.cairo: hash_subtree_path()
    let mut data: Vec<MaybeRelocatable> = Vec::with_capacity(header.proof.mmr_path.len());
    for bytes_data in header.proof.mmr_path.iter() {
        // Left-pad to 32 bytes (big-endian), then interpret as a Felt252
        let mut wide = [0u8; 32];
        let copy_len = core::cmp::min(bytes_data.len(), 32);
        wide[32 - copy_len..].copy_from_slice(&bytes_data[bytes_data.len() - copy_len..]);

        let felt = Felt252::from_bytes_be_slice(&wide);

        // Debug: show the single felt written for this path element
        // println!("Processing MMR path element (felt): 0x{:x}", felt);

        data.push(MaybeRelocatable::from(felt));
    }

    vm.load_data(mmr_path_ptr, &data)?;

    Ok(())
}
