use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};
use pathfinder_common::trie::TrieNode;
use pathfinder_crypto::Felt;
use strum_macros::FromRepr;

use crate::cairo::{structs::CairoFelt, traits::CairoType, FELT_0, FELT_1};

#[derive(FromRepr, Debug)]
pub enum FunctionId {
    Storage = 0,
}

pub struct CairoStorage(CairoFelt);

impl CairoStorage {
    pub fn new(value: CairoFelt) -> Self {
        Self(value)
    }

    pub fn storage(&self) -> CairoFelt {
        self.0.clone()
    }

    pub fn handler(&self, function_id: FunctionId) -> CairoFelt {
        match function_id {
            FunctionId::Storage => self.storage(),
        }
    }
}

impl From<CairoFelt> for CairoStorage {
    fn from(value: CairoFelt) -> Self {
        Self(value)
    }
}

#[derive(Debug)]
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
            TrieNode::Binary { left, right } => vec![
                FELT_0,
                Felt252::from_bytes_be(&left.to_be_bytes()),
                Felt252::from_bytes_be(&right.to_be_bytes()),
                FELT_0,
            ]
            .into_iter(),
            TrieNode::Edge { child, path } => vec![
                FELT_1,
                Felt252::from_bytes_be(&child.to_be_bytes()),
                Felt252::from_bytes_be(&Felt::from_bits(&path).unwrap().to_be_bytes()),
                Felt252::from(path.len()),
            ]
            .into_iter(),
        }
    }
}

impl CairoType for CairoTrieNode {
    fn from_memory(
        vm: &cairo_vm::vm::vm_core::VirtualMachine,
        address: cairo_vm::types::relocatable::Relocatable,
    ) -> Result<Self, MemoryError> {
        let node_type: u8 = (*vm.get_integer((address + 0)?)?).try_into().unwrap();
        match node_type {
            0 => Ok(Self(TrieNode::Binary {
                left: Felt::from_be_bytes(vm.get_integer((address + 1)?)?.to_bytes_be()).unwrap(),
                right: Felt::from_be_bytes(vm.get_integer((address + 2)?)?.to_bytes_be()).unwrap(),
            })),
            1 => Ok(Self(TrieNode::Edge {
                child: Felt::from_be_bytes(vm.get_integer((address + 1)?)?.to_bytes_be()).unwrap(),
                path: Felt::from_be_bytes(vm.get_integer((address + 2)?)?.to_bytes_be())
                    .unwrap()
                    .view_bits()
                    .to_bitvec(),
            })),
            _ => Err(MemoryError::ErrorRetrievingMessage("node type can be either 0 or 1".into())),
        }
    }
    fn to_memory(
        &self,
        vm: &mut cairo_vm::vm::vm_core::VirtualMachine,
        address: cairo_vm::types::relocatable::Relocatable,
    ) -> Result<Relocatable, MemoryError> {
        match &self.0 {
            TrieNode::Binary { left, right } => {
                vm.insert_value((address + 0)?, FELT_0)?;
                vm.insert_value((address + 1)?, Felt252::from_bytes_be(&left.to_be_bytes()))?;
                vm.insert_value((address + 2)?, Felt252::from_bytes_be(&right.to_be_bytes()))?;
                vm.insert_value((address + 3)?, FELT_0)?;
            }
            TrieNode::Edge { child, path } => {
                vm.insert_value((address + 0)?, FELT_1)?;
                vm.insert_value((address + 1)?, Felt252::from_bytes_be(&child.to_be_bytes()))?;
                vm.insert_value(
                    (address + 2)?,
                    Felt252::from_bytes_be(&Felt::from_bits(path).unwrap().to_be_bytes()),
                )?;
                vm.insert_value((address + 3)?, Felt252::from(path.len()))?;
            }
        };
        Ok((address + 4)?)
    }
    fn n_fields(_vm: &VirtualMachine, _address: Relocatable) -> Result<usize, MemoryError> {
        Ok(4)
    }
}
