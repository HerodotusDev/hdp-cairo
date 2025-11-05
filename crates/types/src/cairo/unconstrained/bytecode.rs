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
        let words_64bit_len: usize = (*vm.get_integer((address + 0)?)?).try_into().unwrap();
        let words_64bit = vm
            .get_integer_range((address + 1)?, words_64bit_len)?
            .into_iter()
            .map(|e| *e)
            .collect::<Vec<_>>();
        let last_input_word = *vm.get_integer((address + (words_64bit_len + 1))?)?;
        let last_input_num_bytes = *vm.get_integer((address + (words_64bit_len + 2))?)?;
        Ok(Self {
            words_64bit,
            last_input_word,
            last_input_num_bytes,
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
        Ok((address + (words_64bit_len + 3))?)
    }
    fn n_fields(vm: &VirtualMachine, address: Relocatable) -> Result<usize, MemoryError> {
        let words_64bit_len: usize = (*vm.get_integer((address + 0)?)?).try_into().unwrap();
        Ok(words_64bit_len + 3)
    }
}

impl From<Bytes> for BytecodeLeWords {
    fn from(value: Bytes) -> Self {
        let bytes: &[u8] = value.as_ref();

        let words_64bit: Vec<Felt252> = bytes
            .chunks_exact(8)
            .map(|chunk| {
                let word = u64::from_le_bytes(chunk.try_into().expect("chunks_exact guarantees 8 bytes"));
                Felt252::from(word)
            })
            .collect();

        let remainder = bytes.chunks_exact(8).remainder();
        let last_input_num_bytes = remainder.len() as u64;

        let last_input_word = remainder
            .iter()
            .enumerate()
            .fold(0u64, |acc, (i, &byte)| acc | ((byte as u64) << (i * 8)));

        BytecodeLeWords {
            words_64bit,
            last_input_word: Felt252::from(last_input_word),
            last_input_num_bytes: Felt252::from(last_input_num_bytes),
        }
    }
}
