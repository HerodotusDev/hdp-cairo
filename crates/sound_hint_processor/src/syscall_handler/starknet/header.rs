use crate::syscall_handler::Memorizer;
use cairo_vm::hint_processor::builtin_hint_processor::dict_manager::DictManager;
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use std::cell::RefCell;
use std::rc::Rc;
use syscall_handler::traits::CallHandler;
use syscall_handler::{SyscallExecutionError, SyscallResult};
use types::cairo::starknet::header::StarknetBlock;
use types::{
    cairo::{starknet::header::FunctionId, structs::Felt, traits::CairoType},
    keys::starknet::header::CairoKey,
};

#[derive(Debug)]
pub struct HeaderCallHandler {
    pub memorizer: Memorizer,
    pub dict_manager: Rc<RefCell<DictManager>>,
}

impl HeaderCallHandler {
    pub fn new(memorizer: Memorizer, dict_manager: Rc<RefCell<DictManager>>) -> Self {
        Self { memorizer, dict_manager }
    }
}

#[allow(refining_impl_trait)]
impl CallHandler for HeaderCallHandler {
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
        let mut ptr = self.memorizer.read_key(key.hash(), self.dict_manager.clone())?;
        let field_len: usize = vm.get_integer(ptr)?.as_ref().clone().try_into().unwrap();
        println!("Field length: {:?}", field_len);

        ptr = (ptr + 1)?; // Increment ptr by 1, handling potential overflow
        let fields = vm
            .get_integer_range(ptr, field_len)?
            .into_iter()
            .map(|f| f.as_ref().clone().into())
            .collect::<Vec<Felt252>>();
        // data.resize(1024, 0);
        println!("Fields: {:?}", fields);

        Ok(StarknetBlock::from_fields(fields).handle(function_id))
    }
}
