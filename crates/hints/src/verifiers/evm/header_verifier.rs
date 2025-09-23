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
use types::proofs::{evm, header::HeaderMmrMeta};

use crate::vars;

pub const HINT_HEADERS_WITH_MMR_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(batch_evm.headers_with_mmr))";

pub fn hint_headers_with_mmr_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proofs = exec_scopes.get::<evm::Proofs>(vars::scopes::BATCH_EVM)?;

    insert_value_into_ap(vm, Felt252::from(proofs.headers_with_mmr.len()))
}

pub const HINT_VM_ENTER_SCOPE: &str =
    "vm_enter_scope({'header_with_mmr_evm': batch_evm.headers_with_mmr[ids.idx - 1], '__dict_manager': __dict_manager})";

pub fn hint_vm_enter_scope(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proofs = exec_scopes.get::<evm::Proofs>(vars::scopes::BATCH_EVM)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();

    let headers_with_mmr: Box<dyn Any> = Box::new(proofs.headers_with_mmr[idx - 1].clone());
    let dict_manager: Box<dyn Any> = Box::new(exec_scopes.get::<Rc<RefCell<DictManager>>>(vars::scopes::DICT_MANAGER)?);
    exec_scopes.enter_scope(HashMap::from([
        (String::from(vars::scopes::HEADER_WITH_MMR_EVM), headers_with_mmr),
        (String::from(vars::scopes::DICT_MANAGER), dict_manager),
    ]));

    Ok(())
}

pub const HINT_HEADERS_WITH_MMR_HEADERS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(header_with_mmr_evm.headers))";

pub fn hint_headers_with_mmr_headers_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header_with_mmr = exec_scopes.get::<HeaderMmrMeta<evm::header::Header>>(vars::scopes::HEADER_WITH_MMR_EVM)?;

    insert_value_into_ap(vm, Felt252::from(header_with_mmr.headers.len()))
}

pub const HINT_SET_HEADER: &str =
    "header_evm = header_with_mmr_evm.headers[ids.idx - 1]\nsegments.write_arg(ids.rlp, [int(x, 16) for x in header_evm.rlp])";

pub fn hint_set_header(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let headers_with_mmr = exec_scopes.get::<HeaderMmrMeta<evm::header::Header>>(vars::scopes::HEADER_WITH_MMR_EVM)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();

    let header = headers_with_mmr.headers[idx - 1].clone();
    let rlp_le_chunks: Vec<MaybeRelocatable> = header
        .rlp
        .chunks(8)
        .map(|chunk| MaybeRelocatable::from(Felt252::from_bytes_be_slice(&chunk.iter().rev().copied().collect::<Vec<_>>())))
        .collect();

    exec_scopes.insert_value::<evm::header::Header>(vars::scopes::HEADER_EVM, header);

    let rlp_ptr = get_ptr_from_var_name(vars::ids::RLP, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    vm.load_data(rlp_ptr, &rlp_le_chunks)?;

    Ok(())
}

pub const HINT_RLP_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(header_evm.rlp))";

pub fn hint_rlp_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header = exec_scopes.get::<evm::header::Header>(vars::scopes::HEADER_EVM)?;

    insert_value_into_ap(vm, Felt252::from(header.rlp.chunks(8).count()))
}
pub const HINT_LEAF_IDX: &str = "memory[ap] = to_felt_or_relocatable(len(header_evm.proof.leaf_idx))";

pub fn hint_leaf_idx(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header = exec_scopes.get::<evm::header::Header>(vars::scopes::HEADER_EVM)?;

    insert_value_into_ap(vm, Felt252::from(header.proof.leaf_idx))
}

pub const HINT_MMR_PATH_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(header_evm.proof.mmr_path))";

pub fn hint_mmr_path_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header = exec_scopes.get::<evm::header::Header>(vars::scopes::HEADER_EVM)?;

    insert_value_into_ap(vm, Felt252::from(header.proof.mmr_path.len()))
}

pub const HINT_MMR_PATH: &str = "segments.write_arg(ids.mmr_path, header_evm.proof.mmr_path)";

pub fn hint_mmr_path(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header = exec_scopes.get::<evm::header::Header>(vars::scopes::HEADER_EVM)?;
    let mmr_path_ptr = get_ptr_from_var_name(vars::ids::MMR_PATH, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    // Convert each Bytes element into a 32-byte big-endian value, then split into (low, high) 128-bit felts.
    let mut data: Vec<MaybeRelocatable> = Vec::with_capacity(header.proof.mmr_path.len() * 2);
    for bytes_data in header.proof.mmr_path.iter() {
        let mut wide = [0u8; 32];
        let copy_len = core::cmp::min(bytes_data.len(), 32);
        wide[32 - copy_len..].copy_from_slice(&bytes_data[bytes_data.len() - copy_len..]);

        let high = Felt252::from_bytes_be_slice(&wide[..16]);
        let low = Felt252::from_bytes_be_slice(&wide[16..]);

        // Uint256 layout in Cairo memory: low then high
        data.push(MaybeRelocatable::from(low));
        data.push(MaybeRelocatable::from(high));
    }

    vm.load_data(mmr_path_ptr, &data)?;

    Ok(())
}


// Poseidon path variant: write mmr_path as a flat array of felts (one felt per Bytes element).
pub const HINT_MMR_PATH_FELTS: &str =
    "segments.write_arg(ids.mmr_path, [int(x, 16) for x in header_evm.proof.mmr_path])";

pub fn hint_mmr_path_felts(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header = exec_scopes.get::<evm::header::Header>(vars::scopes::HEADER_EVM)?;
    let mmr_path_ptr = get_ptr_from_var_name(vars::ids::MMR_PATH, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    // Each element is a felt (<= 252 bits). Convert Bytes to Felt252 big-endian.
    let mut data: Vec<MaybeRelocatable> = Vec::with_capacity(header.proof.mmr_path.len());
    for bytes_data in header.proof.mmr_path.iter() {
        // Left-pad to 32 bytes, then interpret as big-endian Felt252 (modulus reduction handled by library).
        let mut wide = [0u8; 32];
        let copy_len = core::cmp::min(bytes_data.len(), 32);
        wide[32 - copy_len..].copy_from_slice(&bytes_data[bytes_data.len() - copy_len..]);

        let felt = Felt252::from_bytes_be_slice(&wide);
        data.push(MaybeRelocatable::from(felt));
    }

    vm.load_data(mmr_path_ptr, &data)?;
    Ok(())
}

// Hint to expose mmr_hashing_function (0=Poseidon, 1=Keccak) from batch_evm to Cairo.
pub const HINT_MMR_HASHING_FUNCTION: &str = "memory[ap] = to_felt_or_relocatable(batch_evm.mmr_hashing_function)";

pub fn hint_mmr_hashing_function(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proofs = exec_scopes.get::<evm::Proofs>(vars::scopes::BATCH_EVM)?;
    let v: u8 = match proofs.mmr_hashing_function {
        types::HashingFunction::Poseidon => 0,
        types::HashingFunction::Keccak => 1,
    };
    insert_value_into_ap(vm, Felt252::from(v))
}