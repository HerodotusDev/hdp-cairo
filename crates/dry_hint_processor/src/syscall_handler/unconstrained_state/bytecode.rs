use alloy::{
    network::Ethereum,
    primitives::Bytes,
    providers::{Provider, RootProvider},
    transports::http::reqwest::Url,
};
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use syscall_handler::{traits::CallHandler, SyscallExecutionError, SyscallResult};
use types::{
    cairo::{new_syscalls::CairoVec, traits::CairoType, unconstrained_state::FunctionId},
    keys::evm::{
        account::{CairoKey, Key},
        get_corresponding_rpc_url,
    },
};

#[derive(Debug, Default)]
pub struct BytecodeCallHandler;

#[allow(refining_impl_trait)]
impl CallHandler for BytecodeCallHandler {
    type Key = Key;
    type Id = FunctionId;
    type CallHandlerResult = CairoVec;

    fn derive_key(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Key> {
        let ret = CairoKey::from_memory(vm, *ptr)?;
        *ptr = (*ptr + CairoKey::n_fields(vm, *ptr)?)?;
        ret.try_into()
            .map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))
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

    async fn handle(&mut self, key: Self::Key, function_id: Self::Id, _vm: &VirtualMachine) -> SyscallResult<Self::CallHandlerResult> {
        let rpc_url = get_corresponding_rpc_url(&key).map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?;
        let provider = RootProvider::<Ethereum>::new_http(Url::parse(&rpc_url).unwrap());
        let value = match function_id {
            FunctionId::Bytecode => provider
                .get_code_at(key.address)
                .block_id(key.block_number.into())
                .await
                .map(|f| f.to_le_64_bit_words()),
        }
        .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?;
        Ok(value)
    }
}

trait ToLe64BitWordsCairoVec {
    fn to_le_64_bit_words(self) -> CairoVec;
}

impl ToLe64BitWordsCairoVec for Bytes {
    //! TODO: @beeinger this needs testing!!!
    fn to_le_64_bit_words(self) -> CairoVec {
        let len = self.len();
        let remaining = (len % 8) as u8;
        let mut words = vec![(len as u64 - remaining as u64) / 8];

        // Process only complete 8-byte words
        for i in (0..len - remaining as usize).step_by(8) {
            let mut word: u64 = 0;
            for j in 0..8 {
                word |= (self[i + j] as u64) << (j * 8);
            }
            words.push(word);
        }

        // Process remaining bytes (if any)
        let (last_input_word, last_input_num_bytes) = if remaining > 0 {
            let start_idx = len - remaining as usize;
            let mut last_word: u64 = 0;
            for i in 0..remaining as usize {
                last_word |= (self[start_idx + i] as u64) << (i * 8);
            }
            (last_word, remaining as u64)
        } else {
            (0, 0)
        };

        // Convert to Felt252: [complete_words_len, complete_words..., last_input_word, last_input_num_bytes]
        let result: Vec<Felt252> = words
            .into_iter()
            .map(Felt252::from)
            .chain([Felt252::from(last_input_word), Felt252::from(last_input_num_bytes)])
            .collect();

        CairoVec(result)
    }
}
