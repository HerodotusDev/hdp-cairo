pub mod account_verifier;
pub mod header_verifier;
pub mod mmr_verifier;
pub mod receipt_verifier;
pub mod storage_item_verifier;
pub mod transaction_verifier;

use crate::vars;
use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::{get_integer_from_var_name, insert_value_into_ap};
use cairo_vm::{
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::{any::Any, collections::HashMap};
use types::proofs::evm;
use types::ChainProofs;

pub const HINT_HEADERS_WITH_MMR_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(batch_evm.headers_with_mmr_evm))";

pub fn hint_headers_with_mmr_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let proofs = exec_scopes.get::<evm::Proofs>(vars::scopes::BATCH_EVM)?;

    insert_value_into_ap(vm, Felt252::from(proofs.headers_with_mmr.len()))
}

pub const HINT_VM_ENTER_SCOPE: &str = "vm_enter_scope({'batch_evm': chain_proofs[ids.idx - 1].value, '__dict_manager': __dict_manager})";

pub fn hint_vm_enter_scope(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let chain_proofs = exec_scopes.get::<Vec<ChainProofs>>(vars::scopes::CHAIN_PROOFS)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();

    let batch: Box<dyn Any> = match chain_proofs[idx - 1].clone() {
        ChainProofs::EthereumMainnet(proofs) => Box::new(proofs),
        ChainProofs::EthereumSepolia(proofs) => Box::new(proofs),
        ChainProofs::StarknetMainnet(proofs) => Box::new(proofs),
        ChainProofs::StarknetSepolia(proofs) => Box::new(proofs),
    };
    let dict_manager: Box<dyn Any> = Box::new(exec_scopes.get_dict_manager()?);

    exec_scopes.enter_scope(HashMap::from([
        (String::from(vars::scopes::BATCH_EVM), batch),
        (String::from(vars::scopes::DICT_MANAGER), dict_manager),
    ]));

    Ok(())
}
