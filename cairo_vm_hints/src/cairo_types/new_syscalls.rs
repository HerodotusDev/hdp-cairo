use crate::cairo_types::traits::CairoType;
use cairo_type_derive::{CairoType, FieldOffsetGetters};
use cairo_vm::types::relocatable::Relocatable;
use cairo_vm::vm::errors::memory_errors::MemoryError;
use cairo_vm::vm::vm_core::VirtualMachine;
use cairo_vm::Felt252;

#[allow(unused)]
#[derive(FieldOffsetGetters, CairoType)]
pub struct CallContractRequest {
    // The address of the L2 contract to call.
    pub contract_address: Felt252,
    // The selector of the function to call.
    pub selector: Felt252,
    // The calldata.
    pub calldata_start: Felt252,
    pub calldata_end: Felt252,
}

#[allow(unused)]
#[derive(FieldOffsetGetters, CairoType)]
pub struct CallContractResponse {
    pub retdata_start: Felt252,
    pub retdata_end: Felt252,
}
