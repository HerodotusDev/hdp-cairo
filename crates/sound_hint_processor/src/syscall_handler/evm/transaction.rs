use std::{cell::RefCell, rc::Rc};

use cairo_vm::{
    hint_processor::builtin_hint_processor::dict_manager::DictManager, types::relocatable::Relocatable, vm::vm_core::VirtualMachine,
    Felt252,
};
use syscall_handler::{traits::CallHandler, SyscallExecutionError, SyscallResult};
use types::{
    cairo::{
        evm::transaction::{CairoTransaction, FunctionId},
        structs::Uint256,
        traits::CairoType,
    },
    keys::evm::transaction::CairoKey,
};

use crate::syscall_handler::Memorizer;

#[derive(Debug)]
pub struct TransactionCallHandler {
    pub memorizer: Memorizer,
    pub dict_manager: Rc<RefCell<DictManager>>,
}

impl TransactionCallHandler {
    pub fn new(memorizer: Memorizer, dict_manager: Rc<RefCell<DictManager>>) -> Self {
        Self { memorizer, dict_manager }
    }
}

#[allow(refining_impl_trait)]
impl CallHandler for TransactionCallHandler {
    type Key = CairoKey;
    type Id = FunctionId;
    type CallHandlerResult = Uint256;

    fn derive_key(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Key> {
        let ret = CairoKey::from_memory(vm, *ptr)?;
        *ptr = (*ptr + CairoKey::n_fields(vm, *ptr)?)?;
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
        let mut data = vm.get_integer(ptr)?.to_bytes_le().to_vec();

        let tx_type = data[0];
        let mut extra_len = 0;
        if tx_type > 0 && tx_type < 4 {
            data.remove(0);
            extra_len = 1;
        }

        data.resize(128000, 0); // 128kb is max tx size
        let header =
            alloy_rlp::Header::decode(&mut data.as_slice()).map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))?;
        let length = header.length_with_payload() + extra_len;
        let rlp = vm
            .get_integer_range(ptr, (length + 7) / 8)?
            .into_iter()
            .flat_map(|f| f.to_bytes_le().into_iter().take(8))
            .take(length)
            .collect::<Vec<u8>>();

        Ok(CairoTransaction::rlp_decode(&rlp).handle(function_id))
    }
}
