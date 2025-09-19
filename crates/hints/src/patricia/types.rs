//! Contains the core data structures and type definitions used throughout the Patricia Merkle tree implementation.
//!
//! This module defines everything from the basic representation of tree components like `NodeEdge` and `StorageLeaf`,
//! to structural helpers like `Height` and `NodePath`. It also includes types for representing tree modifications
//! (`TreeUpdate`) and the necessary machinery for traversing the tree's history (`PreimageNodeIterator`).

use std::{
    collections::{HashMap, HashSet},
    ops::Sub,
};

use cairo_type_derive::FieldOffsetGetters;
use cairo_vm::{
    types::{errors::math_errors::MathError, relocatable::Relocatable},
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
};
use num_bigint::BigUint;
use num_traits::ToPrimitive;
use serde::{Deserialize, Serialize};
use types::{cairo::traits::CairoType, Felt252};

use crate::patricia::{
    error::PatriciaHintError,
    tree::{empty_triplet, get_children},
};

/// Represents a child branch of a node, abstracting away the bit manipulation.
pub enum Child {
    Left,
    Right,
}

impl Child {
    /// Returns the bit value associated with this child (0 for Left, 1 for Right).
    pub fn bit(&self) -> u64 {
        match self {
            Child::Left => 0,
            Child::Right => 1,
        }
    }
}

/// Represents an edge in the Patricia tree, which is a compressed path of nodes.
/// This structure is directly mapped to and from the Cairo VM's memory.
#[derive(FieldOffsetGetters)]
pub struct NodeEdge {
    /// The number of bits in the compressed path.
    pub length: Felt252,
    /// The sequence of bits representing the path.
    pub path: Felt252,
    /// The hash of the node at the end of the edge.
    pub bottom: Felt252,
}

impl CairoType for NodeEdge {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        Ok(Self {
            length: vm.get_integer((address + 0)?)?.into_owned(),
            path: vm.get_integer((address + 1)?)?.into_owned(),
            bottom: vm.get_integer((address + 2)?)?.into_owned(),
        })
    }

    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<Relocatable, MemoryError> {
        vm.insert_value((address + 0)?, self.length)?;
        vm.insert_value((address + 1)?, self.path)?;
        vm.insert_value((address + 2)?, self.bottom)?;
        Ok((address + 3)?)
    }

    fn n_fields(_vm: &VirtualMachine, _address: Relocatable) -> Result<usize, MemoryError> {
        Ok(3)
    }
}

/// Defines the mode of the Patricia tree, typically for contract classes or state.
#[derive(Clone, Debug)]
pub enum PatriciaTreeMode {
    Class,
    State,
}

/// Represents the index of a leaf in the tree, which corresponds to a storage key.
pub type TreeIndex = BigUint;

/// Describes the case when decoding a branch node during a tree update traversal.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum DecodeNodeCase {
    /// Only the left child is part of the update.
    Left,
    /// Only the right child is part of the update.
    Right,
    /// Both children are part of the update.
    Both,
}

/// A newtype representing the height of the Patricia tree or a subtree.
#[derive(Debug, Copy, Clone, PartialEq, Default, Eq, Hash, Serialize, Deserialize)]
pub struct Height(pub u64);

impl From<u64> for Height {
    fn from(val: u64) -> Self {
        Height(val)
    }
}

impl From<Height> for u64 {
    fn from(h: Height) -> Self {
        h.0
    }
}

impl TryFrom<Felt252> for Height {
    type Error = MathError;

    fn try_from(value: Felt252) -> Result<Self, Self::Error> {
        let height = value.to_u64().ok_or(MathError::Felt252ToU64Conversion(Box::new(value)))?;
        Ok(Self(height))
    }
}

impl Sub<u64> for Height {
    type Output = Self;

    fn sub(self, rhs: u64) -> Self::Output {
        Self(self.0 - rhs)
    }
}

/// A newtype representing the length of a path or an edge.
#[derive(Debug, Copy, Clone, PartialEq, Default, Eq)]
pub struct Length(pub u64);

impl From<u64> for Length {
    fn from(val: u64) -> Self {
        Length(val)
    }
}

impl From<Length> for u64 {
    fn from(l: Length) -> Self {
        l.0
    }
}

impl Sub<u64> for Length {
    type Output = Self;

    fn sub(self, rhs: u64) -> Self::Output {
        Self(self.0 - rhs)
    }
}

/// A newtype representing the path from the root to a node in the tree.
#[derive(Debug, Clone, PartialEq, Default, Eq, Hash)]
pub struct NodePath(pub BigUint);

impl From<BigUint> for NodePath {
    fn from(val: BigUint) -> Self {
        NodePath(val)
    }
}

impl From<NodePath> for BigUint {
    fn from(p: NodePath) -> Self {
        p.0
    }
}

/// Represents a leaf in the state tree, containing a single value.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct StorageLeaf {
    pub value: Felt252,
}

impl StorageLeaf {
    /// Creates a new storage leaf with the given value.
    pub fn new(value: Felt252) -> Self {
        Self { value }
    }

    /// Creates an empty storage leaf (with value 0).
    pub fn empty() -> Self {
        Self::new(Felt252::ZERO)
    }
}

/// Represents a change to a Patricia tree.
/// A tree is either modified at a leaf, or one or both of its children are modified.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TreeUpdate<LF>
where
    LF: Clone,
{
    /// A branch node where children have been updated. The `Box` contains the updates
    /// for the left and right children, respectively.
    Tuple(Box<UpdateTree<LF>>, Box<UpdateTree<LF>>),
    /// A leaf node that has been created or modified.
    Leaf(LF),
}

/// An optional `TreeUpdate`, where `None` signifies no modification at this node.
pub type UpdateTree<LF> = Option<TreeUpdate<LF>>;

/// A map from a tree index to a `TreeUpdate`, representing one layer of modifications.
pub type Layer<LF> = HashMap<TreeIndex, TreeUpdate<LF>>;

/// A temporary structure holding the results of decoding a branch node.
#[derive(Clone, Debug)]
pub struct DecodedNode<'a, LF>
where
    LF: Clone,
{
    pub left_child: &'a Option<TreeUpdate<LF>>,
    pub right_child: &'a Option<TreeUpdate<LF>>,
    pub case: DecodeNodeCase,
}

/// A helper for speeding up the VM by skipping hash validations that are known to be correct.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PatriciaSkipValidationRunner {
    pub verified_addresses: HashSet<Relocatable>,
}

/// A map from a node's hash to its pre-image (i.e., its children or edge data).
pub type Preimage = HashMap<Felt252, Vec<Felt252>>;

/// A canonical representation of a node, consisting of (length, path, hash).
/// For binary nodes, length and path are zero.
pub type Triplet = (Felt252, Felt252, Felt252);

/// Uniquely identifies the start of a descent in the tree traversal algorithm.
#[derive(Debug, Clone, PartialEq, Default, Eq, Hash)]
pub struct DescentStart(pub Height, pub NodePath);

/// Represents a path of descent through the tree.
#[derive(Debug, Clone, PartialEq, Default, Eq)]
pub struct DescentPath(pub Length, pub NodePath);

/// A map that guides the tree traversal, indicating where long descents can be taken.
pub type DescentMap = HashMap<DescentStart, DescentPath>;

/// Represents a node within the historical (pre-image) tree structure.
#[allow(clippy::large_enum_variant)]
pub enum PreimageNode<'preimage> {
    /// A leaf node.
    Leaf,
    /// A branch node with optional left and right children.
    Branch {
        left: Option<PreimageNodeIterator<'preimage>>,
        right: Option<PreimageNodeIterator<'preimage>>,
    },
}

/// An iterator for traversing a Patricia tree based on its pre-image data.
/// This is used to reconstruct the state of the tree before modifications.
pub struct PreimageNodeIterator<'preimage> {
    height: Height,
    preimage: &'preimage Preimage,
    node: Triplet,
    is_done: bool,
}

impl<'preimage> PreimageNodeIterator<'preimage> {
    /// Creates a new iterator starting from a given node.
    pub fn new(height: Height, preimage: &'preimage Preimage, node: Triplet) -> Self {
        Self {
            height,
            preimage,
            node,
            is_done: false,
        }
    }
}

impl<'preimage> Iterator for PreimageNodeIterator<'preimage> {
    type Item = Result<PreimageNode<'preimage>, PatriciaHintError>;

    fn next(&mut self) -> Option<Self::Item> {
        if self.is_done {
            return None;
        }
        self.is_done = true;

        // At height 0, we are at a leaf.
        if self.height.0 == 0 {
            return Some(Ok(PreimageNode::Leaf));
        }

        // Otherwise, we are at a branch. Try to get its children.
        let (left, right) = match get_children(self.preimage, &self.node) {
            Ok(children) => children,
            Err(e) => return Some(Err(e)),
        };
        let empty_node = empty_triplet();

        // Recursively create iterators for non-empty children.
        let left_child = if left == empty_node {
            None
        } else {
            Some(PreimageNodeIterator::new(self.height - 1u64, self.preimage, left))
        };
        let right_child = if right == empty_node {
            None
        } else {
            Some(PreimageNodeIterator::new(self.height - 1u64, self.preimage, right))
        };

        Some(Ok(PreimageNode::Branch {
            left: left_child,
            right: right_child,
        }))
    }
}
