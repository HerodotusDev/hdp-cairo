use std::borrow::Cow;

use cairo_vm::{
    types::relocatable::{MaybeRelocatable, Relocatable},
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};
use types::cairo::traits::CairoType;

#[derive(Debug, Clone, Copy)]
struct Limb([u8; 12]);

#[derive(Debug, Clone)]
pub struct UInt384 {
    pub d0: Limb,
    pub d1: Limb,
    pub d2: Limb,
    pub d3: Limb,
}

impl<'a> From<Cow<'a, Felt252>> for Limb {
    fn from(felt_cow: Cow<'a, Felt252>) -> Self {
        Limb::from(*felt_cow)
    }
}

impl From<Felt252> for Limb {
    fn from(felt: Felt252) -> Self {
        let bytes32 = felt.to_bytes_be();
        let mut result = [0u8; 12];
        result.copy_from_slice(&bytes32[20..32]);
        Limb(result)
    }
}

impl From<Limb> for u128 {
    fn from(limb: Limb) -> Self {
        let mut result: u128 = 0;
        for &byte in limb.0.iter() {
            result = (result << 8) | u128::from(byte);
        }
        result
    }
}

impl UInt384 {
    pub fn to_python_list(&self) -> Vec<u128> {
        vec![self.d0.into(), self.d1.into(), self.d2.into(), self.d3.into()]
    }

    pub fn to_bytes(&self) -> Vec<u8> {
        let mut bytes = Vec::with_capacity(48); // 384 bits = 48 bytes
        
        bytes.extend(self.d3.0);
        bytes.extend(self.d2.0);
        bytes.extend(self.d1.0);
        bytes.extend(self.d0.0);
        
        bytes
    }
}

impl CairoType for UInt384 {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        Ok(Self {
            d0: Limb::from(*vm.get_integer((address + 0)?)?),
            d1: Limb::from(*vm.get_integer((address + 1)?)?),
            d2: Limb::from(*vm.get_integer((address + 2)?)?),
            d3: Limb::from(*vm.get_integer((address + 3)?)?),
        })
    }

    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        vm.insert_value((address + 0)?, Felt252::from_bytes_be_slice(&self.d0.0))?;
        vm.insert_value((address + 1)?, Felt252::from_bytes_be_slice(&self.d1.0))?;
        vm.insert_value((address + 2)?, Felt252::from_bytes_be_slice(&self.d2.0))?;
        vm.insert_value((address + 3)?, Felt252::from_bytes_be_slice(&self.d3.0))?;
        Ok((address + 4)?)
    }

    fn n_fields(_vm: &VirtualMachine, _address: Relocatable) -> Result<usize, MemoryError> {
        Ok(4)
    }
}

#[derive(Debug, Clone)]
pub struct ModuloCircuit {
    pub constants_ptr: Relocatable,
    pub add_offsets_ptr: Relocatable,
    pub mul_offsets_ptr: Relocatable,
    pub output_offsets_ptr: Relocatable,
    pub constants_ptr_len: Felt252,
    pub input_len: Felt252,
    pub witnesses_len: Felt252,
    pub output_len: Felt252,
    pub continuous_output: Felt252,
    pub add_mod_n: Felt252,
    pub mul_mod_n: Felt252,
    pub n_assert_eq: Felt252,
    pub name: Felt252,
    pub curve_id: Felt252,
}

impl ModuloCircuit {
    pub fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        Ok(Self {
            constants_ptr: vm.get_relocatable((address + 0)?)?,
            add_offsets_ptr: vm.get_relocatable((address + 1)?)?,
            mul_offsets_ptr: vm.get_relocatable((address + 2)?)?,
            output_offsets_ptr: vm.get_relocatable((address + 3)?)?,
            constants_ptr_len: *vm.get_integer((address + 4)?)?,
            input_len: *vm.get_integer((address + 5)?)?,
            witnesses_len: *vm.get_integer((address + 6)?)?,
            output_len: *vm.get_integer((address + 7)?)?,
            continuous_output: *vm.get_integer((address + 8)?)?,
            add_mod_n: *vm.get_integer((address + 9)?)?,
            mul_mod_n: *vm.get_integer((address + 10)?)?,
            n_assert_eq: *vm.get_integer((address + 11)?)?,
            name: *vm.get_integer((address + 12)?)?,
            curve_id: *vm.get_integer((address + 13)?)?,
        })
    }

    pub fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        vm.insert_value((address + 0)?, MaybeRelocatable::from(self.constants_ptr))?;
        vm.insert_value((address + 1)?, MaybeRelocatable::from(self.add_offsets_ptr))?;
        vm.insert_value((address + 2)?, MaybeRelocatable::from(self.mul_offsets_ptr))?;
        vm.insert_value((address + 3)?, MaybeRelocatable::from(self.output_offsets_ptr))?;
        vm.insert_value((address + 4)?, self.constants_ptr_len)?;
        vm.insert_value((address + 5)?, self.input_len)?;
        vm.insert_value((address + 6)?, self.witnesses_len)?;
        vm.insert_value((address + 7)?, self.output_len)?;
        vm.insert_value((address + 8)?, MaybeRelocatable::from(self.continuous_output))?;
        vm.insert_value((address + 9)?, self.add_mod_n)?;
        vm.insert_value((address + 10)?, self.mul_mod_n)?;
        vm.insert_value((address + 11)?, self.n_assert_eq)?;
        vm.insert_value((address + 12)?, self.name)?;
        vm.insert_value((address + 13)?, self.curve_id)?;
        Ok((address + 14)?)
    }

    pub fn n_fields() -> usize {
        14
    }
}
