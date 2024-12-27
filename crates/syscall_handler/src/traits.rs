use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use types::cairo::traits::CairoType;

use crate::{SyscallResult, WriteResponseResult};

pub trait SyscallHandler {
    type Request;
    type Response;
    fn read_request(&mut self, vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Request>;
    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response>;
    fn write_response(&mut self, response: Self::Response, vm: &mut VirtualMachine, ptr: &mut Relocatable) -> WriteResponseResult;
}

pub trait CallHandler {
    type Key;
    type Id;
    type CallHandlerResult: CairoType;

    fn derive_key(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Key>;
    fn derive_id(selector: Felt252) -> SyscallResult<Self::Id>;
    async fn handle(&mut self, key: Self::Key, function_id: Self::Id, vm: &VirtualMachine) -> SyscallResult<Self::CallHandlerResult>;
}
