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
use types::{
    proofs::{evm, header::HeaderMmrMeta},
    HashingFunction,
};

use crate::{vars, verifiers::bytes_to_u256_be};

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

pub const HINT_AP_HEADER_IS_POSEIDON: &str = "memory[ap] = to_felt_or_relocatable(batch_evm.headers_with_mmr[ids.idx - 1].is_poseidon())";

pub fn hint_ap_header_is_poseidon(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proofs = exec_scopes.get::<evm::Proofs>(vars::scopes::BATCH_EVM)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();

    insert_value_into_ap(
        vm,
        Felt252::from(matches!(
            proofs.headers_with_mmr[idx - 1].mmr_meta.hasher,
            HashingFunction::Poseidon
        )),
    )?;
    Ok(())
}

pub const HINT_AP_HEADER_IS_KECCAK: &str = "memory[ap] = to_felt_or_relocatable(batch_evm.headers_with_mmr[ids.idx - 1].is_keccak())";

pub fn hint_ap_header_is_keccak(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proofs = exec_scopes.get::<evm::Proofs>(vars::scopes::BATCH_EVM)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();

    insert_value_into_ap(
        vm,
        Felt252::from(matches!(proofs.headers_with_mmr[idx - 1].mmr_meta.hasher, HashingFunction::Keccak)),
    )?;
    Ok(())
}

pub const HINT_ENTER_SCOPE_HEADER_WITH_MMR: &str =
    "vm_enter_scope({'header_evm_with_mmr': batch_evm.headers_with_mmr[ids.idx - 1], '__dict_manager': __dict_manager})";

pub fn hint_enter_scope_header_with_mmr(
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
        (String::from(vars::scopes::HEADER_EVM_WITH_MMR), headers_with_mmr),
        (String::from(vars::scopes::DICT_MANAGER), dict_manager),
    ]));
    Ok(())
}

pub const HINT_HEADERS_WITH_MMR_HEADERS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(header_evm_with_mmr.headers))";

pub fn hint_headers_with_mmr_headers_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header_with_mmr = exec_scopes.get::<HeaderMmrMeta<evm::header::Header>>(vars::scopes::HEADER_EVM_WITH_MMR)?;
    insert_value_into_ap(vm, Felt252::from(header_with_mmr.headers.len()))
}

pub const HINT_SET_HEADER: &str = "header_evm = header_evm_with_mmr.headers[ids.idx - 1]";

pub fn hint_set_header(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let headers_with_mmr = exec_scopes.get::<HeaderMmrMeta<evm::header::Header>>(vars::scopes::HEADER_EVM_WITH_MMR)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();

    let header = headers_with_mmr.headers[idx - 1].clone();
    exec_scopes.insert_value::<evm::header::Header>(vars::scopes::HEADER_EVM, header);

    Ok(())
}

pub const HINT_SET_RLP: &str = "segments.write_arg(ids.rlp, [int(x, 16) for x in header_evm.rlp])";

pub fn hint_set_rlp(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header = exec_scopes.get::<evm::header::Header>(vars::scopes::HEADER_EVM)?;
    let rlp_le_chunks: Vec<MaybeRelocatable> = header
        .rlp
        .chunks(8)
        .map(|chunk| MaybeRelocatable::from(Felt252::from_bytes_be_slice(&chunk.iter().rev().copied().collect::<Vec<_>>())))
        .collect();

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

pub const HINT_RLP_BYTE_LEN: &str = "memory[ap] = to_felt_or_relocatable(header_evm.rlp.byte_len())";

pub fn hint_rlp_byte_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header = exec_scopes.get::<evm::header::Header>(vars::scopes::HEADER_EVM)?;
    insert_value_into_ap(
        vm,
        Felt252::from(
            alloy_rlp::Header::decode(&mut header.rlp.to_vec().as_slice())
                .unwrap()
                .length_with_payload(),
        ),
    )
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

pub const HINT_MMR_PATH_KECCAK: &str = "segments.write_arg(ids.mmr_path_keccak, [int(x, 16) for x in header_evm.proof.mmr_path])";

pub fn hint_mmr_path_keccak(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header = exec_scopes.get::<evm::header::Header>(vars::scopes::HEADER_EVM)?;
    let mmr_path_ptr = get_ptr_from_var_name(vars::ids::MMR_PATH_KECCAK, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let mut data: Vec<MaybeRelocatable> = Vec::with_capacity(header.proof.mmr_path.len() * 2);
    for mmr_path_bytes in header.proof.mmr_path.iter() {
        let mmr_path_bytes = bytes_to_u256_be(mmr_path_bytes)?;
        data.push(MaybeRelocatable::from(Felt252::from_bytes_be_slice(&mmr_path_bytes[16..])));
        data.push(MaybeRelocatable::from(Felt252::from_bytes_be_slice(&mmr_path_bytes[..16])));
    }

    vm.load_data(mmr_path_ptr, &data)?;

    Ok(())
}

pub const HINT_MMR_PATH_POSEIDON: &str = "segments.write_arg(ids.mmr_path_poseidon, [int(x, 16) for x in header_evm.proof.mmr_path])";

pub fn hint_mmr_path_poseidon(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header = exec_scopes.get::<evm::header::Header>(vars::scopes::HEADER_EVM)?;
    let mmr_path_ptr = get_ptr_from_var_name(vars::ids::MMR_PATH_POSEIDON, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let mut data: Vec<MaybeRelocatable> = Vec::with_capacity(header.proof.mmr_path.len());
    for mmr_path_bytes in header.proof.mmr_path.iter() {
        let mmr_path_bytes = bytes_to_u256_be(mmr_path_bytes)?;
        data.push(MaybeRelocatable::from(Felt252::from_bytes_be_slice(&mmr_path_bytes)));
    }

    vm.load_data(mmr_path_ptr, &data)?;
    Ok(())
}
