use cairo_type_derive::FieldOffsetGetters;
use cairo_vm::Felt252;

#[allow(unused)]
#[derive(FieldOffsetGetters)]
pub struct CallContractRequest {
    // The address of the L2 contract to call.
    contract_address: Felt252,
    // The selector of the function to call.
    selector: Felt252,
    // The calldata.
    calldata_start: Felt252,
    calldata_end: Felt252,
}

#[allow(unused)]
#[derive(FieldOffsetGetters)]
pub struct CallContractResponse {
    retdata_start: Felt252,
    retdata_end: Felt252,
}
