use cairo_type_derive::FieldOffsetGetters;
use cairo_vm::types::relocatable::Relocatable;
use cairo_vm::Felt252;

#[allow(unused)]
#[derive(FieldOffsetGetters)]
pub struct StorageReadRequest {
    pub selector: Felt252,
    pub address: Felt252,
}

#[allow(unused)]
#[derive(FieldOffsetGetters)]
pub struct StorageReadResponse {
    pub value: Felt252,
}

#[allow(unused)]
#[derive(FieldOffsetGetters)]
pub struct StorageRead {
    pub request: StorageReadRequest,
    pub response: StorageReadResponse,
}

#[allow(unused)]
#[derive(FieldOffsetGetters)]
pub struct StorageWrite {
    pub selector: Felt252,
    pub address: Felt252,
    pub value: Felt252,
}

#[derive(FieldOffsetGetters)]
pub struct CallContractRequest {
    #[allow(unused)]
    pub selector: Felt252,
    #[allow(unused)]
    pub contract_address: Felt252,
    #[allow(unused)]
    pub function_selector: Felt252,
    #[allow(unused)]
    pub calldata_size: Felt252,
    #[allow(unused)]
    pub calldata: Relocatable,
}

#[derive(FieldOffsetGetters)]
pub struct CallContractResponse {
    #[allow(unused)]
    pub retdata_size: Felt252,
    #[allow(unused)]
    pub retdata: Relocatable,
}

#[derive(FieldOffsetGetters)]
pub struct CallContract {
    #[allow(unused)]
    pub request: CallContractRequest,
    #[allow(unused)]
    pub response: CallContractResponse,
}
