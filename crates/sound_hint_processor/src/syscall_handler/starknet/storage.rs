use crate::syscall_handler::Memorizer;
use cairo_vm::hint_processor::builtin_hint_processor::dict_manager::DictManager;
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use types::cairo::structs::Felt;
use std::cell::RefCell;
use std::rc::Rc;
use syscall_handler::traits::CallHandler;
use syscall_handler::{SyscallExecutionError, SyscallResult};
use types::cairo::starknet::storage::CairoStorage;
use types::{
    cairo::{starknet::storage::FunctionId, structs::Uint256, traits::CairoType},
    keys::starknet::storage::CairoKey,
};

#[derive(Debug)]
pub struct StorageCallHandler {
    pub memorizer: Memorizer,
    pub dict_manager: Rc<RefCell<DictManager>>,
}

impl StorageCallHandler {
    pub fn new(memorizer: Memorizer, dict_manager: Rc<RefCell<DictManager>>) -> Self {
        Self { memorizer, dict_manager }
    }
}

#[allow(refining_impl_trait)]
impl CallHandler for StorageCallHandler {
    type Key = CairoKey;
    type Id = FunctionId;
    type CallHandlerResult = Felt;

    fn derive_key(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Key> {
        let ret = CairoKey::from_memory(vm, *ptr)?;
        *ptr = (*ptr + CairoKey::n_fields())?;
        Ok(ret)
    }

    fn derive_id(selector: Felt252) -> SyscallResult<Self::Id> {
        Self::Id::from_repr(selector.try_into().map_err(|e| SyscallExecutionError::InvalidSyscallInput {
            input: selector,
            info: format!("{}", e),
        })?)
        .ok_or(SyscallExecutionError::InvalidSyscallInput {
            input: selector,
            info: "Invalid function identifier".to_string(),
        })
    }

    async fn handle(&mut self, key: Self::Key, function_id: Self::Id, vm: &VirtualMachine) -> SyscallResult<Self::CallHandlerResult> {
        let ptr = self.memorizer.read_key(key.hash(), self.dict_manager.clone())?;
        let data = vm.get_integer(ptr)?;
        Ok(CairoStorage::new(Felt::from(data.as_ref().clone())).handler(function_id))
    }
}
