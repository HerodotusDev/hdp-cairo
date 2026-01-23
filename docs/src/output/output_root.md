# Output Root

The output root is a Merkle root over computation results. HDP follows the OpenZeppelin `StandardMerkleTree` approach with double-hashed leaves.

## Key properties

- Leaves are hashed twice with Keccak.
- The tree is built over unordered leaves.
- Results are endian-adjusted for Solidity compatibility.

## What gets hashed

The leaf list is derived from the Cairo module return data (`retdata`). The output root commits to the module's results, not the full execution trace.

## Implementation

See `compute_merkle_root` in `src/utils/merkle.cairo`.
