use std::{cell::RefCell, rc::Rc};

use cairo_vm::{
    hint_processor::builtin_hint_processor::dict_manager::DictManager,
    types::relocatable::{MaybeRelocatable, Relocatable},
    vm::{
        errors::{hint_errors::HintError, memory_errors::MemoryError},
        vm_core::VirtualMachine,
    },
};
use types::{cairo::traits::CairoType, Felt252};

use crate::SyscallResult;

#[derive(Debug)]
pub struct Memorizer {
    pub dict_ptr: Relocatable,
}

impl Memorizer {
    pub const DEFAULT_VALUE: Felt252 = Felt252::MAX;

    pub fn new(dict_ptr: Relocatable) -> Self {
        Self { dict_ptr }
    }

    pub fn derive(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Memorizer> {
        let ret = Memorizer::from_memory(vm, *ptr)?;
        *ptr = (*ptr + Memorizer::n_fields(vm, *ptr)?)?;
        Ok(ret)
    }

    pub fn read_key_int(&self, key: &MaybeRelocatable, dict_manager: Rc<RefCell<DictManager>>) -> Result<Felt252, HintError> {
        dict_manager
            .borrow_mut()
            .get_tracker_mut(self.dict_ptr)?
            .get_value(key)?
            .get_int()
            .ok_or(HintError::NoValueForKey(Box::new(key.clone())))
    }

    pub fn read_key_ptr(&self, key: &MaybeRelocatable, dict_manager: Rc<RefCell<DictManager>>) -> Result<Relocatable, HintError> {
        dict_manager
            .borrow_mut()
            .get_tracker_mut(self.dict_ptr)?
            .get_value(key)?
            .get_relocatable()
            .ok_or(HintError::NoValueForKey(Box::new(key.clone())))
    }

    pub fn set_key(
        &self,
        key: &MaybeRelocatable,
        value: &MaybeRelocatable,
        dict_manager: Rc<RefCell<DictManager>>,
    ) -> Result<(), HintError> {
        dict_manager.borrow_mut().get_tracker_mut(self.dict_ptr)?.insert_value(key, value);
        Ok(())
    }
}

impl CairoType for Memorizer {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        let segment_index: isize = (*vm.get_integer((address + 0)?)?).try_into().unwrap();
        let offset: usize = (*vm.get_integer((address + 1)?)?).try_into().unwrap();

        Ok(Self {
            dict_ptr: Relocatable::from((segment_index, offset)),
        })
    }
    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        vm.insert_value((address + 0)?, MaybeRelocatable::from(Felt252::from(self.dict_ptr.segment_index)))?;
        vm.insert_value((address + 1)?, MaybeRelocatable::from(Felt252::from(self.dict_ptr.offset)))?;
        Ok((address + 2)?)
    }
    fn n_fields(_vm: &VirtualMachine, _address: Relocatable) -> Result<usize, MemoryError> {
        Ok(2)
    }
}
