use std::collections::HashMap;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_ptr_from_var_name, insert_value_into_ap},
    },
    types::{exec_scope::ExecutionScopes, relocatable::MaybeRelocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use types::proofs::{evm, header::HeaderMmrMeta};

use crate::{vars, verifiers::bytes_to_u256_be};

pub const HINT_HEADERS_WITH_MMR_META_PEAKS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(header_evm_with_mmr.mmr_meta.peaks))";

pub fn hint_headers_with_mmr_meta_peaks_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header_with_mmr = exec_scopes.get::<HeaderMmrMeta<evm::header::Header>>(vars::scopes::HEADER_EVM_WITH_MMR)?;

    insert_value_into_ap(vm, Felt252::from(header_with_mmr.mmr_meta.peaks.len()))
}

pub const HINT_HEADERS_WITH_MMR_META_ID: &str = "memory[ap] = to_felt_or_relocatable(header_evm_with_mmr.mmr_meta.id)";

pub fn hint_headers_with_mmr_meta_id(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header_with_mmr = exec_scopes.get::<HeaderMmrMeta<evm::header::Header>>(vars::scopes::HEADER_EVM_WITH_MMR)?;

    insert_value_into_ap(vm, Felt252::from_bytes_be_slice(&header_with_mmr.mmr_meta.id.0))
}

pub const HINT_HEADERS_WITH_MMR_META_ROOT: &str = "memory[ap] = to_felt_or_relocatable(header_evm_with_mmr.mmr_meta.root)";

pub fn hint_headers_with_mmr_meta_root(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header_with_mmr = exec_scopes.get::<HeaderMmrMeta<evm::header::Header>>(vars::scopes::HEADER_EVM_WITH_MMR)?;

    insert_value_into_ap(vm, Felt252::from_bytes_be_slice(&header_with_mmr.mmr_meta.root))
}

pub const HINT_HEADERS_WITH_MMR_META_SIZE: &str = "memory[ap] = to_felt_or_relocatable(header_evm_with_mmr.mmr_meta.size)";

pub fn hint_headers_with_mmr_meta_size(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header_with_mmr = exec_scopes.get::<HeaderMmrMeta<evm::header::Header>>(vars::scopes::HEADER_EVM_WITH_MMR)?;

    insert_value_into_ap(vm, Felt252::from(header_with_mmr.mmr_meta.size))
}

pub const HINT_HEADERS_WITH_MMR_PEAKS_POSEIDON: &str = "segments.write_arg(ids.peaks_poseidon, header_evm_with_mmr.mmr_meta.peaks)";

pub fn hint_headers_with_mmr_peaks_poseidon(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header_with_mmr = exec_scopes.get::<HeaderMmrMeta<evm::header::Header>>(vars::scopes::HEADER_EVM_WITH_MMR)?;
    let peaks_ptr = get_ptr_from_var_name(vars::ids::PEAKS_POSEIDON, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    vm.load_data(
        peaks_ptr,
        &header_with_mmr
            .mmr_meta
            .peaks
            .into_iter()
            .map(|f| MaybeRelocatable::from(Felt252::from_bytes_be_slice(&f)))
            .collect::<Vec<MaybeRelocatable>>(),
    )?;

    Ok(())
}

pub const HINT_HEADERS_WITH_MMR_META_CHAIN_ID: &str = "memory[ap] = to_felt_or_relocatable(header_evm_with_mmr.mmr_meta.chain_id)";

pub fn hint_headers_with_mmr_meta_chain_id(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header_with_mmr = exec_scopes.get::<HeaderMmrMeta<evm::header::Header>>(vars::scopes::HEADER_EVM_WITH_MMR)?;

    insert_value_into_ap(vm, Felt252::from(header_with_mmr.mmr_meta.chain_id))
}

// Keccak peaks writer: writes Vec<Bytes>[32] into memory as contiguous Uint256 (low, high) pairs.
pub const HINT_HEADERS_WITH_MMR_PEAKS_KECCAK: &str = "segments.write_arg(ids.peaks_keccak, header_evm_with_mmr.mmr_meta.peaks)";

pub fn hint_headers_with_mmr_peaks_keccak(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header_with_mmr = exec_scopes.get::<HeaderMmrMeta<evm::header::Header>>(vars::scopes::HEADER_EVM_WITH_MMR)?;
    let peaks_ptr = get_ptr_from_var_name(vars::ids::PEAKS_KECCAK, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let mut data: Vec<MaybeRelocatable> = Vec::with_capacity(header_with_mmr.mmr_meta.peaks.len() * 2);
    for peak in header_with_mmr.mmr_meta.peaks.iter() {
        let peak_bytes = bytes_to_u256_be(peak)?;

        data.push(MaybeRelocatable::from(Felt252::from_bytes_be_slice(&peak_bytes[16..])));
        data.push(MaybeRelocatable::from(Felt252::from_bytes_be_slice(&peak_bytes[..16])));
    }

    vm.load_data(peaks_ptr, &data)?;
    Ok(())
}

// Keccak root splitters: read 32-byte root and split into 2x16-byte felts (high, low) big-endian.
pub const HINT_HEADERS_WITH_MMR_META_ROOT_LOW: &str = "memory[ap] = to_felt_or_relocatable(header_evm_with_mmr.mmr_meta.root_low)";

pub fn hint_headers_with_mmr_meta_root_low(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header_with_mmr = exec_scopes.get::<HeaderMmrMeta<evm::header::Header>>(vars::scopes::HEADER_EVM_WITH_MMR)?;
    let root_bytes = bytes_to_u256_be(header_with_mmr.mmr_meta.root.as_ref())?;
    insert_value_into_ap(vm, Felt252::from_bytes_be_slice(&root_bytes[16..]))
}

pub const HINT_HEADERS_WITH_MMR_META_ROOT_HIGH: &str = "memory[ap] = to_felt_or_relocatable(header_evm_with_mmr.mmr_meta.root_high)";

pub fn hint_headers_with_mmr_meta_root_high(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header_with_mmr = exec_scopes.get::<HeaderMmrMeta<evm::header::Header>>(vars::scopes::HEADER_EVM_WITH_MMR)?;
    let root_bytes = bytes_to_u256_be(header_with_mmr.mmr_meta.root.as_ref())?;
    insert_value_into_ap(vm, Felt252::from_bytes_be_slice(&root_bytes[..16]))
}
