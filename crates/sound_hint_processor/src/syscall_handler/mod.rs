use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData, dict_manager::DictManager, hint_utils::get_ptr_from_var_name,
    },
    types::{
        exec_scope::ExecutionScopes,
        relocatable::{MaybeRelocatable, Relocatable},
    },
    vm::{
        errors::{hint_errors::HintError, memory_errors::MemoryError},
        vm_core::VirtualMachine,
    },
    Felt252,
};
use evm::SyscallHandlerWrapper;
use hints::vars;
use std::{any::Any, cell::RefCell, collections::HashMap, rc::Rc};
use syscall_handler::SyscallResult;
use types::cairo::traits::CairoType;

pub mod evm;
pub mod starknet;

#[derive(Debug)]
pub struct Memorizer {
    dict_ptr: Relocatable,
}

impl Memorizer {
    pub fn new(dict_ptr: Relocatable) -> Self {
        Self { dict_ptr }
    }

    pub fn derive(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Memorizer> {
        let ret = Memorizer::from_memory(vm, *ptr)?;
        *ptr = (*ptr + Memorizer::n_fields())?;
        Ok(ret)
    }

    pub fn read_key(&self, key: Felt252, dict_manager: Rc<RefCell<DictManager>>) -> Result<Felt252, HintError> {
        let key = MaybeRelocatable::from(key);
        dict_manager
            .borrow_mut()
            .get_tracker_mut(self.dict_ptr)?
            .get_value(&key)?
            .get_int()
            .ok_or(HintError::NoValueForKey(Box::new(key.clone())))
    }
}

impl CairoType for Memorizer {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        let segment_index: isize = (*vm.get_integer((address + 0)?)?).try_into().unwrap();
        let offset: usize = (*vm.get_integer((address + 1)?)?).try_into().unwrap();

        Ok(Self {
            dict_ptr: Relocatable::from((segment_index, offset)),
        })
    }
    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<(), MemoryError> {
        vm.insert_value((address + 0)?, MaybeRelocatable::from(Felt252::from(self.dict_ptr.segment_index)))?;
        vm.insert_value((address + 1)?, MaybeRelocatable::from(Felt252::from(self.dict_ptr.offset)))?;
        Ok(())
    }
    fn n_fields() -> usize {
        2
    }
}

pub const SYSCALL_HANDLER_CREATE: &str = "if 'syscall_handler' not in globals():\n    from contract_bootloader.syscall_handler import SyscallHandler\n    syscall_handler = SyscallHandler(segments=segments, dict_manager=__dict_manager)";

pub fn syscall_handler_create(
    _vm: &mut VirtualMachine,
    exec_scopes: &mut ExecutionScopes,
    _hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    if let Err(HintError::VariableNotInScopeError(_)) = exec_scopes.get::<SyscallHandlerWrapper>(vars::scopes::SYSCALL_HANDLER) {
        let syscall_handler = SyscallHandlerWrapper::new(exec_scopes.get_dict_manager()?);
        exec_scopes.insert_value(vars::scopes::SYSCALL_HANDLER, syscall_handler);
    }

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
