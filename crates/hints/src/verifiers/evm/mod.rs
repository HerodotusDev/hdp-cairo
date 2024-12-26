use crate::vars;
use cairo_vm::{
    hint_processor::builtin_hint_processor::{builtin_hint_processor_definition::HintProcessorData, hint_utils::insert_value_into_ap},
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::collections::HashMap;
use types::proofs::Proofs;

pub mod account_verifier;
pub mod header_verifier;
pub mod receipt_verifier;
pub mod storage_item_verifier;
pub mod transaction_verifier;

pub const HINT_HEADERS_WITH_MMR_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(batch.headers_with_mmr))";

pub fn hint_headers_with_mmr_headers_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proofs = exec_scopes.get::<Proofs>(vars::scopes::BATCH)?;

    insert_value_into_ap(vm, Felt252::from(proofs.headers_with_mmr.len()))
}
