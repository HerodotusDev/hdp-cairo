use cairo_vm::{vm::errors::memory_errors::MemoryError, Felt252};
use strum_macros::FromRepr;

use crate::{
    cairo::{structs::Felt, traits::CairoType, FELT_0, FELT_1},
    proofs::starknet::storage::{Path, TrieNode},
};

#[derive(FromRepr, Debug)]
pub enum FunctionId {
    Storage = 0,
}

pub struct CairoStorage(Felt);

impl CairoStorage {
    pub fn new(value: Felt) -> Self {
        Self(value)
    }

    pub fn storage(&self) -> Felt {
        self.0.clone()
    }

    pub fn handler(&self, function_id: FunctionId) -> Felt {
        match function_id {
            FunctionId::Storage => self.storage(),
        }
    }
}

impl From<Felt> for CairoStorage {
    fn from(value: Felt) -> Self {
        Self(value)
    }
}

pub struct CairoTrieNode(pub TrieNode);

impl CairoTrieNode {
    pub fn is_edge(&self) -> bool {
        match &self.0 {
            TrieNode::Binary { left: _, right: _ } => false,
            TrieNode::Edge { child: _, path: _ } => true,
        }
    }
}

use std::vec::IntoIter;

impl IntoIterator for CairoTrieNode {
    type Item = Felt252;
    type IntoIter = IntoIter<Self::Item>;

    fn into_iter(self) -> Self::IntoIter {
        match self.0 {
            TrieNode::Binary { left, right } => vec![FELT_0, left, right, FELT_0].into_iter(),
            TrieNode::Edge { child, path } => vec![FELT_1, child, Felt252::from_hex(&path.value).unwrap(), Felt252::from(path.len)].into_iter(),
        }
    }
}

impl CairoType for CairoTrieNode {
    fn from_memory(vm: &cairo_vm::vm::vm_core::VirtualMachine, address: cairo_vm::types::relocatable::Relocatable) -> Result<Self, MemoryError> {
        let node_type: u8 = (*vm.get_integer((address + 0)?)?).try_into().unwrap();
        match node_type {
            0 => Ok(Self(TrieNode::Binary {
                left: *vm.get_integer((address + 1)?)?,
                right: *vm.get_integer((address + 2)?)?,
            })),
            1 => Ok(Self(TrieNode::Edge {
                child: *vm.get_integer((address + 1)?)?,
                path: Path {
                    value: (*vm.get_integer((address + 2)?)?).to_string(),
                    len: (*vm.get_integer((address + 3)?)?).try_into().unwrap(),
                },
            })),
            _ => Err(MemoryError::ErrorRetrievingMessage("node type can be either 0 or 1".into())),
        }
    }
    fn to_memory(
        &self,
        vm: &mut cairo_vm::vm::vm_core::VirtualMachine,
        address: cairo_vm::types::relocatable::Relocatable,
    ) -> Result<(), MemoryError> {
        match &self.0 {
            TrieNode::Binary { left, right } => {
                vm.insert_value((address + 0)?, FELT_0)?;
                vm.insert_value((address + 1)?, left)?;
                vm.insert_value((address + 2)?, right)?;
                vm.insert_value((address + 3)?, FELT_0)?;
            }
            TrieNode::Edge { child, path } => {
                vm.insert_value((address + 0)?, FELT_1)?;
                vm.insert_value((address + 1)?, child)?;
                vm.insert_value((address + 2)?, Felt252::from_hex(&path.value).unwrap())?;
                vm.insert_value((address + 3)?, Felt252::from(path.len))?;
            }
        };
        Ok(())
    }
    fn n_fields() -> usize {
        4
    }
}
