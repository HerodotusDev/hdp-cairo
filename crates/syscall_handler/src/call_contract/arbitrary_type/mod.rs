pub mod models;
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use models::{ArbitraryTypeInput, ArbitraryTypeOutput};
use serde::{Deserialize, Serialize};
use types::cairo::{
    new_syscalls::{CallContractRequest, CallContractResponse},
    traits::CairoType,
};

use crate::{traits, SyscallResult, WriteResponseResult};

pub const CONTRACT_ADDRESS: Felt252 = Felt252::from_hex_unchecked("0x616e795f74797065"); // 'any_type' in hex

#[derive(Debug, Default, Serialize, Deserialize, Clone)]
pub struct ArbitraryTypeCallContractHandler;

impl traits::SyscallHandler for ArbitraryTypeCallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        let ret = Self::Request::from_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Request::cairo_size())?;
        Ok(ret)
    }

    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let input = ArbitraryTypeInput::from_memory(vm, request.calldata_start)?;
        let output = ArbitraryTypeOutput {
            item_a: input.item_a,
            item_b: input.item_b,
            item_c: input.item_a,
        };

        let retdata_start = vm.add_memory_segment();
        let retdata_end = output.to_memory(vm, retdata_start)?;

        Ok(Self::Response {
            retdata_start,
            retdata_end,
        })
    }

    fn write_response(&mut self, response: Self::Response, vm: &mut VirtualMachine, ptr: &mut Relocatable) -> WriteResponseResult {
        response.to_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Response::cairo_size())?;
        Ok(())
    }
}
