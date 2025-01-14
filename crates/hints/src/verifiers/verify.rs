use crate::vars;
use cairo_vm::hint_processor::builtin_hint_processor::builtin_hint_processor_definition::HintProcessorData;
use cairo_vm::hint_processor::builtin_hint_processor::hint_utils::{get_integer_from_var_name, insert_value_into_ap};
use cairo_vm::{
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use std::{any::Any, collections::HashMap};
use types::ChainProofs;

pub const HINT_CHAIN_PROOFS_LEN: &str = "memory[ap] = to_felt_or_relocatable(len(chain_proofs))";

pub fn hint_chain_proofs_len(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let chain_proofs = exec_scopes.get::<Vec<ChainProofs>>(vars::scopes::CHAIN_PROOFS)?;
    insert_value_into_ap(vm, Felt252::from(chain_proofs.len()))
}

pub const HINT_CHAIN_PROOFS_CHAIN_ID: &str = "memory[ap] = to_felt_or_relocatable(chain_proofs[ids.idx - 1].chain_id)";

pub fn hint_chain_proofs_chain_id(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let chain_proofs = exec_scopes.get::<Vec<ChainProofs>>(vars::scopes::CHAIN_PROOFS)?;
    let idx: usize = get_integer_from_var_name(vars::ids::IDX, vm, &hint_data.ids_data, &hint_data.ap_tracking)?
        .try_into()
        .unwrap();
    insert_value_into_ap(vm, Felt252::from(chain_proofs[idx - 1].chain_id()))
}

pub const HINT_VM_ENTER_SCOPE: &str = "vm_enter_scope({'batch': chain_proofs[ids.idx - 1].value, '__dict_manager': __dict_manager})";

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
        (String::from(vars::scopes::BATCH), batch),
        (String::from(vars::scopes::DICT_MANAGER), dict_manager),
    ]));

    Ok(())
}
