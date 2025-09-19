use std::{cell::RefCell, rc::Rc};

use cairo_vm::{
    hint_processor::builtin_hint_processor::dict_manager::DictManager,
    types::relocatable::{MaybeRelocatable, Relocatable},
    vm::vm_core::VirtualMachine,
    Felt252,
};
use syscall_handler::{memorizer::Memorizer, traits::CallHandler, SyscallExecutionError, SyscallResult};
use types::{
    cairo::{
        evm::receipt::{CairoReceiptWithBloom, FunctionId},
        traits::CairoType,
    },
    keys::evm::receipt::CairoKey,
};
#[derive(Debug)]
pub struct ReceiptCallHandler {
    pub memorizer: Memorizer,
    pub dict_manager: Rc<RefCell<DictManager>>,
}

impl ReceiptCallHandler {
    pub fn new(memorizer: Memorizer, dict_manager: Rc<RefCell<DictManager>>) -> Self {
        Self { memorizer, dict_manager }
    }
}

#[allow(refining_impl_trait)]
impl CallHandler for ReceiptCallHandler {
    type Key = CairoKey;
    type Id = FunctionId;
    type CallHandlerResult = Vec<Felt252>;

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
        let ptr = self
            .memorizer
            .read_key_ptr(&MaybeRelocatable::Int(key.hash()), self.dict_manager.clone())?;

        // data is the rlp-encoded receipt (injected by the verified mpt proof Cairo0 memorizer)
        let mut data = vm.get_integer(ptr)?.to_bytes_le().to_vec();
        let tx_type = data[0];
        let mut extra_len = 0;
        // If not a legacy tx, remove the tx type from the receipt
        if tx_type > 0 && tx_type < 4 {
            // Pop the tx type from the receipt, rest will be valid rlp
            data.remove(0);
            extra_len = 1;
        }

        data.resize(128000, 0); // 128kb is max tx size
        let header =
            alloy_rlp::Header::decode(&mut data.as_slice()).map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))?;
        let length = header.length_with_payload() + extra_len;
        let rlp = vm
            .get_integer_range(ptr, length.div_ceil(8))?
            .into_iter()
            .flat_map(|f| f.to_bytes_le().into_iter().take(8))
            .take(length)
            .collect::<Vec<u8>>();

        if extra_len != 0 {
            Ok(CairoReceiptWithBloom::rlp_decode(&rlp[1..]).handle(function_id))
        } else {
            Ok(CairoReceiptWithBloom::rlp_decode(&rlp).handle(function_id))
        }
    }
}
