pub mod evm;
pub mod starknet;

use cairo_vm::{
    hint_processor::builtin_hint_processor::{builtin_hint_processor_definition::HintProcessorData, hint_utils::get_ptr_from_var_name},
    types::{exec_scope::ExecutionScopes, relocatable::Relocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use evm::CallContractHandler as EvmCallContractHandler;
use hints::vars;
use serde::{Deserialize, Serialize};
use starknet::CallContractHandler as StarknetCallContractHandler;
use std::{any::Any, collections::HashMap, rc::Rc};
use syscall_handler::{felt_from_ptr, run_handler, traits, SyscallExecutionError, SyscallResult, SyscallSelector, WriteResponseResult};
use tokio::{sync::RwLock, task};
use types::cairo::traits::CairoType;
use types::{
    cairo::new_syscalls::{CallContractRequest, CallContractResponse},
    ETHEREUM_MAINNET_CHAIN_ID, ETHEREUM_TESTNET_CHAIN_ID, STARKNET_MAINNET_CHAIN_ID, STARKNET_TESTNET_CHAIN_ID,
};

#[derive(Debug, Default, Serialize, Deserialize, Clone)]
pub struct SyscallHandler {
    #[serde(skip)]
    pub syscall_ptr: Option<Relocatable>,
    pub call_contract_handler: CallContractHandlerRelay,
}

/// SyscallHandler is wrapped in Rc<RefCell<_>> in order
/// to clone the reference when entering and exiting vm scopes
#[derive(Debug, Clone, Default)]
pub struct SyscallHandlerWrapper {
    pub syscall_handler: Rc<RwLock<SyscallHandler>>,
}

impl SyscallHandlerWrapper {
    pub fn new() -> Self {
        Self {
            syscall_handler: Rc::new(RwLock::new(SyscallHandler::default())),
        }
    }
    pub fn set_syscall_ptr(&self, syscall_ptr: Relocatable) {
        let mut syscall_handler = task::block_in_place(|| self.syscall_handler.blocking_write());
        syscall_handler.syscall_ptr = Some(syscall_ptr);
    }

    pub fn syscall_ptr(&self) -> Option<Relocatable> {
        let syscall_handler = task::block_in_place(|| self.syscall_handler.blocking_read());
        syscall_handler.syscall_ptr
    }

    pub async fn execute_syscall(&mut self, vm: &mut VirtualMachine, syscall_ptr: Relocatable) -> Result<(), HintError> {
        let mut syscall_handler = self.syscall_handler.write().await;
        let ptr = &mut syscall_handler
            .syscall_ptr
            .ok_or(HintError::CustomHint(Box::from("syscall_ptr is None")))?;

        assert_eq!(*ptr, syscall_ptr);

        match SyscallSelector::try_from(felt_from_ptr(vm, ptr)?)? {
            SyscallSelector::CallContract => run_handler(&mut syscall_handler.call_contract_handler, ptr, vm).await,
        }?;

        syscall_handler.syscall_ptr = Some(*ptr);

        Ok(())
    }
}

#[derive(Debug, Default, Serialize, Deserialize, Clone)]
pub struct CallContractHandlerRelay {
    pub evm_call_contract_handler: EvmCallContractHandler,
    pub starknet_call_contract_handler: StarknetCallContractHandler,
}

impl traits::SyscallHandler for CallContractHandlerRelay {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        let ret = Self::Request::from_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Request::cairo_size())?;
        Ok(ret)
    }

    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let chain_id = <Felt252 as TryInto<u128>>::try_into(*vm.get_integer((request.calldata_start + 2)?)?)
            .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?;

        match chain_id {
            ETHEREUM_MAINNET_CHAIN_ID | ETHEREUM_TESTNET_CHAIN_ID => self.evm_call_contract_handler.execute(request, vm).await,
            STARKNET_MAINNET_CHAIN_ID | STARKNET_TESTNET_CHAIN_ID => self.starknet_call_contract_handler.execute(request, vm).await,
            _ => Err(SyscallExecutionError::InternalError(Box::from("Unknown chain id"))),
        }
    }

    fn write_response(&mut self, response: Self::Response, vm: &mut VirtualMachine, ptr: &mut Relocatable) -> WriteResponseResult {
        response.to_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Response::cairo_size())?;
        Ok(())
    }
}

pub const SYSCALL_HANDLER_CREATE_MOCK: &str = "if 'syscall_handler' not in globals():\n    from contract_bootloader.syscall_handler import SyscallHandler\n    syscall_handler = SyscallHandler(segments=segments, dict_manager=__dict_manager)";

pub fn syscall_handler_create_mock(
    _vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    exec_scopes.get::<SyscallHandlerWrapper>(vars::scopes::SYSCALL_HANDLER)?;
    Ok(())
}

pub const SYSCALL_HANDLER_CREATE: &str = "from contract_bootloader.dryrun_syscall_handler import DryRunSyscallHandler\nsyscall_handler = DryRunSyscallHandler(segments=segments, dict_manager=__dict_manager)";

pub fn syscall_handler_create(
    _vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let syscall_handler = SyscallHandlerWrapper::new();
    exec_scopes.insert_value(vars::scopes::SYSCALL_HANDLER, syscall_handler);

    Ok(())
}

pub const SYSCALL_HANDLER_SET_SYSCALL_PTR: &str = "syscall_handler.set_syscall_ptr(syscall_ptr=ids.syscall_ptr)";

pub fn syscall_handler_set_syscall_ptr(
    vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let syscall_ptr = get_ptr_from_var_name(vars::ids::SYSCALL_PTR, vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let syscall_handler = exec_scopes.get_mut_ref::<SyscallHandlerWrapper>(vars::scopes::SYSCALL_HANDLER)?;
    syscall_handler.set_syscall_ptr(syscall_ptr);

    Ok(())
}

pub const ENTER_SCOPE_SYSCALL_HANDLER: &str = "vm_enter_scope({'syscall_handler': syscall_handler})";

pub fn enter_scope_syscall_handler(
    _vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let syscall_handler: Box<dyn Any> = Box::new(exec_scopes.get::<SyscallHandlerWrapper>(vars::scopes::SYSCALL_HANDLER)?);
    exec_scopes.enter_scope(HashMap::from_iter([(vars::scopes::SYSCALL_HANDLER.to_string(), syscall_handler)]));

    Ok(())
}
