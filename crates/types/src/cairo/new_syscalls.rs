use std::ops::Deref;

use cairo_type_derive::FieldOffsetGetters;
use cairo_vm::{
    types::relocatable::{MaybeRelocatable, Relocatable},
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};

use super::{traits::CairoType, FELT_1};

#[derive(FieldOffsetGetters, Debug)]
pub struct CallContractRequest {
    // The address of the L2 contract to call.
    pub contract_address: Felt252,
    // The selector of the function to call.
    pub selector: Felt252,
    // The calldata.
    pub calldata_start: Relocatable,
    pub calldata_end: Relocatable,
}

impl CairoType for CallContractRequest {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        let contract_address = *vm.get_integer((address + 0)?)?;
        let selector = *vm.get_integer((address + 1)?)?;
        let calldata_start = vm.get_relocatable((address + 2)?)?;
        let calldata_end = vm.get_relocatable((address + 3)?)?;
        Ok(Self {
            contract_address,
            selector,
            calldata_start,
            calldata_end,
        })
    }
    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        vm.insert_value((address + 0)?, self.contract_address)?;
        vm.insert_value((address + 1)?, self.selector)?;
        vm.insert_value((address + 2)?, self.calldata_start)?;
        vm.insert_value((address + 3)?, self.calldata_end)?;
        Ok((address + 4)?)
    }
    fn n_fields(_vm: &VirtualMachine, _address: Relocatable) -> Result<usize, MemoryError> {
        Ok(4)
    }
}

#[derive(FieldOffsetGetters, Debug)]
pub struct CallContractResponse {
    pub retdata_start: Relocatable,
    pub retdata_end: Relocatable,
}

impl CairoType for CallContractResponse {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        let retdata_start = vm.get_relocatable((address + 0)?)?;
        let retdata_end = vm.get_relocatable((address + 1)?)?;
        Ok(Self {
            retdata_start,
            retdata_end,
        })
    }
    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        vm.insert_value((address + 0)?, self.retdata_start)?;
        vm.insert_value((address + 1)?, self.retdata_end)?;
        Ok((address + 2)?)
    }
    fn n_fields(_vm: &VirtualMachine, _address: Relocatable) -> Result<usize, MemoryError> {
        Ok(2)
    }
}

#[derive(FieldOffsetGetters, Debug)]
pub struct KeccakRequest {
    pub input_start: Relocatable,
    pub input_end: Relocatable,
}

impl CairoType for KeccakRequest {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        let input_start = vm.get_relocatable((address + 0)?)?;
        let input_end = vm.get_relocatable((address + 1)?)?;
        Ok(Self { input_start, input_end })
    }
    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        vm.insert_value((address + 0)?, self.input_start)?;
        vm.insert_value((address + 1)?, self.input_end)?;
        Ok((address + 2)?)
    }
    fn n_fields(_vm: &VirtualMachine, _address: Relocatable) -> Result<usize, MemoryError> {
        Ok(2)
    }
}

#[derive(FieldOffsetGetters, Debug)]
pub struct KeccakResponse {
    pub result_low: Felt252,
    pub result_high: Felt252,
}

impl CairoType for KeccakResponse {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        let result_low = *vm.get_integer((address + 0)?)?;
        let result_high = *vm.get_integer((address + 1)?)?;
        Ok(Self { result_low, result_high })
    }
    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        vm.insert_value((address + 0)?, self.result_low)?;
        vm.insert_value((address + 1)?, self.result_high)?;
        Ok((address + 2)?)
    }
    fn n_fields(_vm: &VirtualMachine, _address: Relocatable) -> Result<usize, MemoryError> {
        Ok(2)
    }
}

#[derive(Clone)]
pub struct CairoVec(pub Vec<Felt252>);

impl FromIterator<Felt252> for CairoVec {
    fn from_iter<T: IntoIterator<Item = Felt252>>(iter: T) -> Self {
        CairoVec(Vec::<Felt252>::from_iter(iter))
    }
}

impl Deref for CairoVec {
    type Target = Vec<Felt252>;
    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl CairoType for CairoVec {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        let len = *vm.get_integer((address + 0)?)?;
        let result = vm
            .get_integer_range((address + 1)?, len.try_into().unwrap())?
            .into_iter()
            .map(|e| *e)
            .collect();
        Ok(result)
    }
    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        vm.insert_value((address + 0)?, self.len())?;
        vm.load_data((address + 1)?, &self.iter().map(MaybeRelocatable::from).collect::<Vec<_>>())?;
        Ok((address + (self.len() + 1))?)
    }
    fn n_fields(vm: &VirtualMachine, address: Relocatable) -> Result<usize, MemoryError> {
        let len = *vm.get_integer((address + 0)?)? + FELT_1;
        Ok(len.try_into().unwrap())
    }
}

impl CairoType for Vec<Felt252> {
    fn from_memory(_vm: &VirtualMachine, _address: Relocatable) -> Result<Self, MemoryError> {
        unreachable!()
    }
    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        vm.load_data((address + 0)?, &self.iter().map(MaybeRelocatable::from).collect::<Vec<_>>())?;
        Ok((address + self.len())?)
    }
    fn n_fields(_vm: &VirtualMachine, _address: Relocatable) -> Result<usize, MemoryError> {
        unreachable!()
    }
}
