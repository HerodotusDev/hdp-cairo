use alloy::primitives::Bytes;
use cairo_vm::{
    types::relocatable::{MaybeRelocatable, Relocatable},
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};
use serde::{Deserialize, Serialize};

use crate::cairo::traits::CairoType;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct BytecodeLeWords {
    pub words_64bit: Vec<Felt252>,
    pub last_input_word: Felt252,
    pub last_input_num_bytes: Felt252,
}

impl CairoType for BytecodeLeWords {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        //? TOOD: @beeinger - should i simply unwrap here? converting to MemoryError does not make much sense
        let words_64bit_len: usize = (*vm.get_integer((address + 0)?)?).try_into().unwrap();
        Ok(Self {
            words_64bit: vm
                .get_integer_range((address + 1)?, words_64bit_len)?
                .into_iter()
                .map(|e| *e)
                .collect::<Vec<_>>(),
            last_input_word: *vm.get_integer((address + (words_64bit_len + 1))?)?,
            last_input_num_bytes: *vm.get_integer((address + (words_64bit_len + 2))?)?,
        })
    }
    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        let words_64bit_len = self.words_64bit.len();
        vm.insert_value((address + 0)?, words_64bit_len)?;
        vm.load_data(
            (address + 1)?,
            &self.words_64bit.iter().map(MaybeRelocatable::from).collect::<Vec<_>>(),
        )?;
        vm.insert_value((address + (words_64bit_len + 1))?, self.last_input_word)?;
        vm.insert_value((address + (words_64bit_len + 2))?, self.last_input_num_bytes)?;
        Ok((address + (self.words_64bit.len() + 3))?)
    }
    fn n_fields(vm: &VirtualMachine, address: Relocatable) -> Result<usize, MemoryError> {
        let words_64bit_len: usize = (*vm.get_integer((address + 0)?)?).try_into().unwrap();
        Ok(words_64bit_len + 3)
    }
}

impl From<Bytes> for BytecodeLeWords {
    fn from(value: Bytes) -> Self {
        let len = value.len();
        let remaining = (len % 8) as u8;
        let mut words = vec![];

        // Process only complete 8-byte words
        for i in (0..len - remaining as usize).step_by(8) {
            let mut word: u64 = 0;
            for j in 0..8 {
                word |= (value[i + j] as u64) << (j * 8);
            }
            words.push(word);
        }

        // Process remaining bytes (if any)
        let (last_input_word, last_input_num_bytes) = if remaining > 0 {
            let start_idx = len - remaining as usize;
            let mut last_word: u64 = 0;
            for i in 0..remaining as usize {
                last_word |= (value[start_idx + i] as u64) << (i * 8);
            }
            (last_word, remaining as u64)
        } else {
            (0, 0)
        };

        BytecodeLeWords {
            words_64bit: words.into_iter().map(Felt252::from).collect(),
            last_input_word: Felt252::from(last_input_word),
            last_input_num_bytes: Felt252::from(last_input_num_bytes),
        }
    }
}
