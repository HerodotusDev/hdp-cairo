use cairo_vm::{
    types::relocatable::{MaybeRelocatable, Relocatable},
    vm::vm_core::VirtualMachine,
    Felt252,
};
use serde::{Deserialize, Serialize};
use types::cairo::{
    new_syscalls::{CallContractRequest, CallContractResponse},
    traits::CairoType,
    FELT_10,
};

use crate::{traits, SyscallResult, WriteResponseResult};

pub const CONTRACT_ADDRESS: Felt252 = Felt252::from_hex_unchecked("0x616e795f74797065"); // 'any_type' in hex

#[derive(Debug, Default, Serialize, Deserialize, Clone)]
pub struct AnyTypeCallContractHandler;

impl traits::SyscallHandler for AnyTypeCallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        let ret = Self::Request::from_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Request::cairo_size())?;
        Ok(ret)
    }

    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let field_len = (request.calldata_end - request.calldata_start)?;
        let fields = vm
            .get_integer_range(request.calldata_start, field_len)?
            .into_iter()
            .map(|f| (*f.as_ref()))
            .collect::<Vec<Felt252>>();

        // we need here macro to deserialize the cairo1 way the CairoType derived structure
        let input = AnyTypeInput {
            item_a: fields[0],
            item_b: fields[1],
            item_c: fields[2],
            item_d: fields[3],
        };

        // we need here macro to serialize the cairo1 way the CairoType derived structure
        let output = AnyTypeOutput {
            item_a: input.item_a,
            item_b: input.item_b,
            item_c: input.item_c,
            item_d: input.item_d,
            item_e: FELT_10,
            item_f: FELT_10,
        };

        let retdata_start = vm.add_memory_segment();
        let retdata_end = vm.load_data(
            retdata_start,
            &[
                output.item_a,
                output.item_b,
                output.item_c,
                output.item_d,
                output.item_e,
                output.item_f,
            ]
            .map(MaybeRelocatable::from),
        )?;

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

struct AnyTypeInput {
    pub item_a: Felt252,
    pub item_b: Felt252,
    pub item_c: Felt252,
    pub item_d: Felt252,
}

struct AnyTypeOutput {
    pub item_a: Felt252,
    pub item_b: Felt252,
    pub item_c: Felt252,
    pub item_d: Felt252,
    pub item_e: Felt252,
    pub item_f: Felt252,
}
