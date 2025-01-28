use cairo_type_derive::FieldOffsetGetters;
use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};

use super::traits::CairoType;

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
    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<(), MemoryError> {
        vm.insert_value((address + 0)?, self.contract_address)?;
        vm.insert_value((address + 1)?, self.selector)?;
        vm.insert_value((address + 2)?, self.calldata_start)?;
        vm.insert_value((address + 3)?, self.calldata_end)?;
        Ok(())
    }
    fn n_fields() -> usize {
        4
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
    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<(), MemoryError> {
        vm.insert_value((address + 0)?, self.retdata_start)?;
        vm.insert_value((address + 1)?, self.retdata_end)?;
        Ok(())
    }
    fn n_fields() -> usize {
        2
    }
}
