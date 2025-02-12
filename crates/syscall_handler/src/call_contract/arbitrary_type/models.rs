use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};
use types::cairo::{structs::CairoFelt, traits::CairoType};

#[derive(Default, Debug, Clone)]
pub struct ArbitraryTypeInput {
    pub item_a: Felt252,
    pub item_b: Vec<Felt252>,
}

impl CairoType for ArbitraryTypeInput {
    fn from_memory(vm: &VirtualMachine, mut address: Relocatable) -> Result<Self, MemoryError> {
        let item_a = *CairoFelt::from_memory(vm, address)?;
        address += CairoFelt::n_fields(vm, address)?;
        let item_b = Vec::<Felt252>::from_memory(vm, address)?;

        Ok(Self { item_a, item_b })
    }

    fn to_memory(&self, vm: &mut VirtualMachine, mut address: Relocatable) -> Result<Relocatable, MemoryError> {
        address = CairoFelt::from(self.item_a).to_memory(vm, address)?;
        address = self.item_b.to_memory(vm, address)?;
        Ok(address)
    }

    fn n_fields(vm: &VirtualMachine, mut address: Relocatable) -> Result<usize, MemoryError> {
        let mut n = CairoFelt::n_fields(vm, address)?;
        address += CairoFelt::n_fields(vm, address)?;
        n += Vec::<Felt252>::n_fields(vm, address)?;
        Ok(n)
    }
}

#[derive(Default, Debug, Clone)]
pub struct ArbitraryTypeOutput {
    pub item_a: Felt252,
    pub item_b: Vec<Felt252>,
    pub item_c: Felt252,
}

impl CairoType for ArbitraryTypeOutput {
    fn from_memory(vm: &VirtualMachine, mut address: Relocatable) -> Result<Self, MemoryError> {
        let item_a = *CairoFelt::from_memory(vm, address)?;
        address += CairoFelt::n_fields(vm, address)?;
        let item_b = Vec::<Felt252>::from_memory(vm, address)?;
        address += Vec::<Felt252>::n_fields(vm, address)?;
        let item_c = *CairoFelt::from_memory(vm, address)?;

        Ok(Self { item_a, item_b, item_c })
    }

    fn to_memory(&self, vm: &mut VirtualMachine, mut address: Relocatable) -> Result<Relocatable, MemoryError> {
        address = CairoFelt::from(self.item_a).to_memory(vm, address)?;
        address = self.item_b.to_memory(vm, address)?;
        address = CairoFelt::from(self.item_c).to_memory(vm, address)?;
        Ok(address)
    }

    fn n_fields(vm: &VirtualMachine, mut address: Relocatable) -> Result<usize, MemoryError> {
        let mut n = CairoFelt::n_fields(vm, address)?;
        address += CairoFelt::n_fields(vm, address)?;
        n += Vec::<Felt252>::n_fields(vm, address)?;
        address += Vec::<Felt252>::n_fields(vm, address)?;
        n += CairoFelt::n_fields(vm, address)?;
        Ok(n)
    }
}
