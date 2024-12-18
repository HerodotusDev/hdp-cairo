use crate::cairo::traits::CairoType;
use alloy::primitives::{Address, B256, B64, U256};
use cairo_type_derive::{CairoType, FieldOffsetGetters};
use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};

#[derive(FieldOffsetGetters, CairoType, Default, Debug)]
pub struct Uint256 {
    pub high: Felt252,
    pub low: Felt252,
}

impl From<u64> for Uint256 {
    fn from(value: u64) -> Self {
        Self {
            low: Felt252::from(value),
            high: Felt252::ZERO,
        }
    }
}

impl From<B64> for Uint256 {
    fn from(value: B64) -> Self {
        let bytes: [u8; 8] = value.0;
        Self {
            low: Felt252::from_bytes_be_slice(&bytes[0..8]),
            high: Felt252::ZERO,
        }
    }
}

impl From<U256> for Uint256 {
    fn from(value: U256) -> Self {
        let bytes: [u8; 32] = value.to_be_bytes();
        Self {
            low: Felt252::from_bytes_be_slice(&bytes[0..16]),
            high: Felt252::from_bytes_be_slice(&bytes[16..32]),
        }
    }
}

impl From<B256> for Uint256 {
    fn from(value: B256) -> Self {
        let bytes: [u8; 32] = value.0;
        Self {
            low: Felt252::from_bytes_be_slice(&bytes[0..16]),
            high: Felt252::from_bytes_be_slice(&bytes[16..32]),
        }
    }
}

impl From<Address> for Uint256 {
    fn from(value: Address) -> Self {
        let bytes: [u8; 20] = *value.0;
        Self {
            low: Felt252::from_bytes_be_slice(&bytes[0..16]),
            high: Felt252::from_bytes_be_slice(&bytes[16..20]),
        }
    }
}

#[allow(unused)]
#[derive(FieldOffsetGetters)]
pub struct CompiledClass {
    compiled_class_version: Felt252,
    n_external_functions: Felt252,
    external_functions: Felt252,
    n_l1_handlers: Felt252,
    l1_handlers: Felt252,
    n_constructors: Felt252,
    constructors: Felt252,
    bytecode_length: Felt252,
    bytecode_ptr: Felt252,
}

#[allow(unused)]
#[derive(FieldOffsetGetters)]
pub struct BuiltinParams {
    builtin_encodings: Felt252,
    builtin_instance_sizes: Felt252,
}
