//! Implements the core off-chain algorithms for building and analyzing Patricia Merkle tree structures.
//!
//! This module provides the foundational logic for the Cairo hints. Its primary responsibilities include:
//! 1. Constructing an "update tree" from a list of modifications (`build_update_tree`).
//! 2. Calculating the `descent_map`, which is crucial for optimizing the on-chain traversal by identifying paths where we can descend
//!    multiple layers at once (`patricia_guess_descents`).
//! 3. Providing helper utilities for decoding nodes and navigating the tree structure.

use std::{
    collections::{HashMap, HashSet},
    ops::{Add, Mul},
};

use cairo_vm::types::errors::math_errors::MathError;
use num_bigint::BigUint;
use num_traits::{One, ToPrimitive, Zero};
use pathfinder_common::{hash::FeltHash, trie::TrieNode};
use pathfinder_crypto::Felt;
use types::Felt252;

use crate::patricia::{
    error::PatriciaHintError,
    types::{
        Child, DecodeNodeCase, DecodedNode, DescentMap, DescentPath, DescentStart, Height, Layer, Length, NodePath, Preimage, PreimageNode,
        PreimageNodeIterator, TreeIndex, TreeUpdate, Triplet, UpdateTree,
    },
};

/// Constructs a `TreeUpdate` from a list of leaf modifications.
///
/// This function simulates the process of building a Merkle tree from the bottom up.
/// It starts with a layer of modified leaves and progressively combines them into parent nodes
/// until only the single root node remains.
///
/// # Arguments
/// * `height` - The total height of the Patricia tree.
/// * `modifications` - A vector of `(index, value)` tuples representing the leaves to be updated.
pub fn build_update_tree<LF>(height: Height, modifications: Vec<(TreeIndex, LF)>) -> UpdateTree<LF>
where
    LF: Clone,
{
    if modifications.is_empty() {
        return None;
    }

    // A layer maps an index within that layer to its corresponding subtree.
    let mut layer: Layer<LF> = modifications
        .into_iter()
        .map(|(index, leaf_fact)| (index, TreeUpdate::Leaf(leaf_fact)))
        .collect();

    // Start from the bottom layer and build up to the root.
    for _ in 0..height.0 {
        let parents: HashSet<TreeIndex> = layer.keys().map(|key| key / 2u64).collect();
        let mut new_layer: Layer<LF> = HashMap::with_capacity(parents.len());

        for index in parents {
            // Take children from the current layer to form parents in the new layer.
            // Using .remove() is efficient as the old layer is discarded after this loop.
            let left_update = layer.remove(&(&index * 2u64));
            let right_update = layer.remove(&(&index * 2u64 + 1u64));

            new_layer.insert(index, TreeUpdate::Tuple(Box::new(left_update), Box::new(right_update)));
        }
        layer = new_layer;
    }

    // The final layer should contain only the root node at index 0.
    debug_assert!(layer.len() == 1, "Final layer must contain only the root");
    layer.remove(&BigUint::zero())
}

/// Decodes a branch node from a `TreeUpdate`, identifying which children are being modified.
/// This is a utility function to simplify hint logic.
///
/// # Returns
/// A `DecodedNode` struct containing references to the children and the modification `case`.
///
/// # Errors
/// Returns `PatriciaHintError::UnexpectedLeaf` if a leaf is passed, or
/// `PatriciaHintError::InvalidTupleNode` for an invalid branch with no children.
pub fn decode_node<LF>(node: &TreeUpdate<LF>) -> Result<DecodedNode<LF>, PatriciaHintError>
where
    LF: Clone,
{
    match node {
        TreeUpdate::Tuple(left, right) => {
            let case = match (left.as_ref(), right.as_ref()) {
                (None, Some(_)) => DecodeNodeCase::Right,
                (Some(_), None) => DecodeNodeCase::Left,
                (Some(_), Some(_)) => DecodeNodeCase::Both,
                (None, None) => return Err(PatriciaHintError::InvalidTupleNode),
            };

            Ok(DecodedNode {
                left_child: left,
                right_child: right,
                case,
            })
        }
        TreeUpdate::Leaf(_) => Err(PatriciaHintError::UnexpectedLeaf),
    }
}

/// Retrieves the children of a node from the `preimage` map.
/// A node can be a binary node (length=0) or an edge node (length>0).
pub fn get_children(preimage: &Preimage, node: &Triplet) -> Result<(Triplet, Triplet), PatriciaHintError> {
    let (length, word, node_hash) = (&node.0, &node.1, &node.2);

    // Case 1: Binary Node. Its children are found directly in the preimage.
    if length.is_zero() {
        let (left_hash, right_hash) = if node_hash.is_zero() {
            (Felt252::ZERO, Felt252::ZERO)
        } else {
            let node_preimage = preimage.get(node_hash).ok_or(PatriciaHintError::PreimageNotFound(*node_hash))?;
            if node_preimage.len() != 2 {
                return Err(PatriciaHintError::InvalidEdgePreimageLength(*node_hash, node_preimage.len()));
            }
            (node_preimage[0], node_preimage[1])
        };
        return Ok((canonic(preimage, left_hash), canonic(preimage, right_hash)));
    }

    // Case 2: Edge Node. The children are derived from the edge itself.
    let length_u64 = length.to_u64().ok_or(MathError::Felt252ToU64Conversion(Box::new(*length)))?;

    // The most significant bit of the word determines if the edge descends left or right.
    if word.to_biguint() >> (length_u64 - 1) == BigUint::zero() {
        // Descends left: the right child is empty.
        Ok(((length - Felt252::ONE, *word, *node_hash), empty_triplet()))
    } else {
        // Descends right: the left child is empty.
        let new_word = word - Felt252::from(BigUint::one() << (length_u64 - 1));
        Ok((empty_triplet(), (length - Felt252::ONE, new_word, *node_hash)))
    }
}

/// Returns the canonical representation of an empty node.
pub fn empty_triplet() -> Triplet {
    (Felt252::ZERO, Felt252::ZERO, Felt252::ZERO)
}

/// Converts a node hash into its canonical `Triplet` representation.
/// If the hash corresponds to an edge node in the preimage, it returns the edge's data.
/// Otherwise, it returns a triplet representing a binary node.
fn canonic(preimage: &Preimage, node_hash: Felt252) -> Triplet {
    if let Some(edge_data) = preimage.get(&node_hash) {
        if edge_data.len() == 3 {
            return (edge_data[0], edge_data[1], edge_data[2]);
        }
    }
    // Default to a binary node representation.
    (Felt252::ZERO, Felt252::ZERO, node_hash)
}

/// Creates an iterator to traverse a tree based on its historical `preimage` data.
fn preimage_tree<'a>(height: Height, preimage: &'a Preimage, node: Triplet) -> PreimageNodeIterator<'a> {
    PreimageNodeIterator::new(height, preimage, node)
}

/// Recursively calculates the `DescentMap` for a given subtree.
///
/// This is the core of the optimization algorithm. It traverses three trees simultaneously:
/// 1. The `update_tree` (representing changes).
/// 2. The `previous_tree` (state before update).
/// 3. The `new_tree` (state after update).
///
/// It finds the longest common path where all three trees descend in the same direction,
/// recording this path in the `descent_map` to allow the VM to skip intermediate steps.
fn get_descents<LF>(
    mut height: Height,
    mut path: NodePath,
    mut update_tree: &UpdateTree<LF>,
    mut previous_tree: Option<PreimageNodeIterator>,
    mut new_tree: Option<PreimageNodeIterator>,
) -> Result<DescentMap, PatriciaHintError>
where
    LF: Clone,
{
    if update_tree.is_none() || height.0 == 0 {
        return Ok(DescentMap::new());
    }

    let orig_height = height;
    let orig_path = path.clone();

    // This loop finds the longest path of single-child descents.
    let (lefts, rights) = loop {
        // --- Step 1: Decode the children for all three trees ---
        let (update_left, update_right) = match update_tree {
            Some(TreeUpdate::Tuple(l, r)) => (l.as_ref(), r.as_ref()),
            _ => break ((&None, None, None), (&None, None, None)), // Stop if we hit a leaf or an empty node in the update tree.
        };

        // This closure is defined inline, and we are intentionally suppressing the
        // clippy::type_complexity warning for it.
        #[allow(clippy::type_complexity)]
        let get_preimage_children: for<'a> fn(
            Option<PreimageNodeIterator<'a>>,
        ) -> Result<
            (Option<PreimageNodeIterator<'a>>, Option<PreimageNodeIterator<'a>>),
            PatriciaHintError,
        > = |tree| match tree {
            None => Ok((None, None)),
            Some(mut iter) => match iter.next().transpose()? {
                None => Ok((None, None)),
                Some(PreimageNode::Leaf) => Err(PatriciaHintError::UnexpectedLeaf),
                Some(PreimageNode::Branch { left, right }) => Ok((left, right)),
            },
        };

        let (previous_left, previous_right) = get_preimage_children(previous_tree)?;
        let (new_left, new_right) = get_preimage_children(new_tree)?;

        // --- Step 2: Determine if we can descend and in which direction ---
        let left_is_empty = update_left.is_none() && previous_left.is_none() && new_left.is_none();
        let right_is_empty = update_right.is_none() && previous_right.is_none() && new_right.is_none();

        let descent_direction = match (left_is_empty, right_is_empty) {
            (true, false) => Some(Child::Right), // Only right child has content, descend right.
            (false, true) => Some(Child::Left),  // Only left child has content, descend left.
            _ => None,                           // Both children have content or both are empty, stop descending.
        };

        if let Some(direction) = descent_direction {
            // --- Step 3: Update state for the next iteration ---
            path = NodePath(path.0 * 2u64 + direction.bit());
            height = Height(height.0 - 1);

            if height.0 == 0 {
                break ((update_left, previous_left, new_left), (update_right, previous_right, new_right));
            }

            match direction {
                Child::Left => {
                    update_tree = update_left;
                    previous_tree = previous_left;
                    new_tree = new_left;
                }
                Child::Right => {
                    update_tree = update_right;
                    previous_tree = previous_right;
                    new_tree = new_right;
                }
            }
        } else {
            // We can't descend further, break and record the children for recursion.
            break ((update_left, previous_left, new_left), (update_right, previous_right, new_right));
        }
    };

    let mut descent_map = DescentMap::new();
    let length = orig_height.0 - height.0;

    // A descent is only meaningful if it spans more than one level.
    if length > 1 {
        let relative_path = path.0.clone() % (BigUint::one() << length);
        descent_map.insert(
            DescentStart(orig_height, orig_path),
            DescentPath(Length(length), NodePath(relative_path)),
        );
    }

    if height.0 > 0 {
        let (left_update, left_prev, left_new) = lefts;
        let (right_update, right_prev, right_new) = rights;

        // Recurse on the left child.
        let left_path = NodePath(path.0.clone().mul(2u64));
        descent_map.extend(get_descents(height - 1, left_path, left_update, left_prev, left_new)?);

        // Recurse on the right child.
        let right_path = NodePath(path.0.mul(2u64).add(1u64));
        descent_map.extend(get_descents(height - 1, right_path, right_update, right_prev, right_new)?);
    }

    Ok(descent_map)
}

/// Builds a `DescentMap` for a Patricia tree update operation.
///
/// This is the main entry point for the descent analysis. It sets up the initial state
/// for the three trees (update, previous, new) and calls the recursive `get_descents` function.
///
/// # Arguments
/// * `height` - The height of the tree.
/// * `node` - The `UpdateTree` representing the modifications.
/// * `preimage` - A map from node hashes to their children, representing the historical state.
/// * `prev_root` - The root hash of the tree *before* the update.
/// * `new_root` - The root hash of the tree *after* the update.
pub fn patricia_guess_descents<LF>(
    height: Height,
    node: UpdateTree<LF>,
    preimage: &Preimage,
    prev_root: BigUint,
    new_root: BigUint,
) -> Result<DescentMap, PatriciaHintError>
where
    LF: Clone,
{
    let node_prev = preimage_tree(height, preimage, canonic(preimage, Felt252::from(prev_root)));
    let node_new = preimage_tree(height, preimage, canonic(preimage, Felt252::from(new_root)));

    get_descents::<LF>(height, NodePath(BigUint::zero()), &node, Some(node_prev), Some(node_new))
}

pub fn generate_preimage<H: FeltHash>(proof: Vec<TrieNode>) -> Preimage {
    HashMap::from_iter(proof.into_iter().map(|node| {
        let hash = node.hash::<H>();
        match node {
            TrieNode::Binary { left, right } => (
                Felt252::from_bytes_be(&hash.to_be_bytes()),
                vec![
                    Felt252::from_bytes_be(&left.to_be_bytes()),
                    Felt252::from_bytes_be(&right.to_be_bytes()),
                ],
            ),
            TrieNode::Edge { child, path } => (
                Felt252::from_bytes_be(&hash.to_be_bytes()),
                vec![
                    Felt252::from_bytes_be(&Felt::from_u64(path.len() as u64).to_be_bytes()),
                    Felt252::from_bytes_be(&Felt::from_bits(&path).unwrap().to_be_bytes()),
                    Felt252::from_bytes_be(&child.to_be_bytes()),
                ],
            ),
        }
    }))
}
