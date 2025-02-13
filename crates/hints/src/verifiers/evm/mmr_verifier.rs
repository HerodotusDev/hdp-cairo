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

use crate::vars;

pub const HINT_HEADERS_WITH_MMR_META_PEAKS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(header_with_mmr_evm.mmr_meta.peaks))";

pub fn hint_headers_with_mmr_meta_peaks_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header_with_mmr = exec_scopes.get::<HeaderMmrMeta<evm::header::Header>>(vars::scopes::HEADER_WITH_MMR_EVM)?;

    insert_value_into_ap(vm, Felt252::from(header_with_mmr.mmr_meta.peaks.len()))
}

pub const HINT_HEADERS_WITH_MMR_META_ID: &str = "memory[ap] = to_felt_or_relocatable(header_with_mmr_evm.mmr_meta.id)";

pub fn hint_headers_with_mmr_meta_id(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header_with_mmr = exec_scopes.get::<HeaderMmrMeta<evm::header::Header>>(vars::scopes::HEADER_WITH_MMR_EVM)?;

    insert_value_into_ap(vm, Felt252::from_bytes_be_slice(&header_with_mmr.mmr_meta.id.0))
}

pub const HINT_HEADERS_WITH_MMR_META_ROOT: &str = "memory[ap] = to_felt_or_relocatable(header_with_mmr_evm.mmr_meta.root)";

pub fn hint_headers_with_mmr_meta_root(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header_with_mmr = exec_scopes.get::<HeaderMmrMeta<evm::header::Header>>(vars::scopes::HEADER_WITH_MMR_EVM)?;

    insert_value_into_ap(vm, Felt252::from_bytes_be_slice(&header_with_mmr.mmr_meta.root))
}

pub const HINT_HEADERS_WITH_MMR_META_SIZE: &str = "memory[ap] = to_felt_or_relocatable(header_with_mmr_evm.mmr_meta.size)";

pub fn hint_headers_with_mmr_meta_size(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header_with_mmr = exec_scopes.get::<HeaderMmrMeta<evm::header::Header>>(vars::scopes::HEADER_WITH_MMR_EVM)?;

    insert_value_into_ap(vm, Felt252::from(header_with_mmr.mmr_meta.size))
}

pub const HINT_HEADERS_WITH_MMR_PEAKS: &str = "segments.write_arg(ids.peaks, header_with_mmr_evm.mmr_meta.peaks)";

pub fn hint_headers_with_mmr_peaks(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let header_with_mmr = exec_scopes.get::<HeaderMmrMeta<evm::header::Header>>(vars::scopes::HEADER_WITH_MMR_EVM)?;
    let peaks_ptr = get_ptr_from_var_name(vars::ids::PEAKS, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

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
