pub mod models;
use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use models::{ArbitraryTypeInput, ArbitraryTypeOutput};
use serde::{Deserialize, Serialize};
use types::cairo::{
    new_syscalls::{CallContractRequest, CallContractResponse},
    traits::CairoType,
};

use crate::{traits, SyscallResult, WriteResponseResult};

pub const CONTRACT_ADDRESS: Felt252 = Felt252::from_hex_unchecked("0x6172626974726172795F74797065"); // 'arbitrary_type' in hex

#[derive(Debug, Default, Serialize, Deserialize, Clone)]
pub struct ArbitraryTypeCallContractHandler;

impl traits::SyscallHandler for ArbitraryTypeCallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, _vm: &VirtualMachine, _ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        unreachable!()
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

    fn write_response(&mut self, _response: Self::Response, _vm: &mut VirtualMachine, _ptr: &mut Relocatable) -> WriteResponseResult {
        unreachable!()
    }
}
