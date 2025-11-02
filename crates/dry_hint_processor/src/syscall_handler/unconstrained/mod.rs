use std::{collections::HashSet, hash::Hash};

use alloy::{
    network::Ethereum,
    providers::{Provider, RootProvider},
};
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine};
use reqwest::Url;
use serde::{Deserialize, Serialize};
use strum_macros::FromRepr;
use syscall_handler::{felt_from_ptr, traits::SyscallHandler, SyscallExecutionError, SyscallResult, WriteResponseResult};
use types::{
    cairo::{
        new_syscalls::{CallContractRequest, CallContractResponse},
        traits::CairoType,
        unconstrained::bytecode::BytecodeLeWords,
    },
    keys::{self, evm::get_corresponding_rpc_url},
    Felt252,
};

#[derive(FromRepr, Debug)]
pub enum CallHandlerId {
    Bytecode = 0,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct CallContractHandler {
    pub key_set: HashSet<DryRunKey>,
}

impl SyscallHandler for CallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, _vm: &VirtualMachine, _ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        unreachable!()
    }

    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let mut calldata = request.calldata_start;

        let call_handler_id = CallHandlerId::try_from(request.contract_address)?;

        let segment_index = felt_from_ptr(vm, &mut calldata)?;
        let offset = felt_from_ptr(vm, &mut calldata)?;

        let _memorizer = Relocatable::from((
            segment_index
                .try_into()
                .map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))?,
            offset
                .try_into()
                .map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))?,
        ));

        let retdata_start = vm.add_memory_segment();
        let mut retdata_end = retdata_start;
        match call_handler_id {
            CallHandlerId::Bytecode => {
                let key: keys::evm::account::Key = keys::evm::account::CairoKey::from_memory(vm, calldata)?
                    .try_into()
                    .map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))?;
                let rpc_url = get_corresponding_rpc_url(&key).map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?;
                let provider = RootProvider::<Ethereum>::new_http(Url::parse(&rpc_url).unwrap());
                let result = provider
                    .get_code_at(key.address)
                    .block_id(key.block_number.into())
                    .await
                    .map(BytecodeLeWords::from)
                    .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?;

                self.key_set.insert(DryRunKey::Bytecode(key));
                retdata_end = result.to_memory(vm, retdata_end)?;
            }
        }

        Ok(Self::Response {
            retdata_start,
            retdata_end,
        })
    }

    fn write_response(&mut self, _response: Self::Response, _vm: &mut VirtualMachine, _ptr: &mut Relocatable) -> WriteResponseResult {
        unreachable!()
    }
}

impl TryFrom<Felt252> for CallHandlerId {
    type Error = SyscallExecutionError;
    fn try_from(value: Felt252) -> Result<Self, Self::Error> {
        Self::from_repr(value.try_into().map_err(|e| Self::Error::InvalidSyscallInput {
            input: value,
            info: format!("{}", e),
        })?)
        .ok_or(Self::Error::InvalidSyscallInput {
            input: value,
            info: "Invalid function identifier".to_string(),
        })
    }
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq, Hash, Clone)]
#[serde(rename_all = "lowercase")]
pub enum DryRunKey {
    Bytecode(keys::evm::account::Key),
}

impl DryRunKey {
    pub fn is_bytecode(&self) -> bool {
        matches!(self, Self::Bytecode(_))
    }
}
