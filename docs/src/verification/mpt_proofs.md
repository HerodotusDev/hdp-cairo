# MPT Proofs

Merkle Patricia Tries (MPTs) are used to prove Ethereum account and storage data.

## What is an MPT?

An MPT is a trie-based authenticated data structure with three node types:

- **Branch**: up to 16 children + value
- **Extension**: shared key prefix and next node
- **Leaf**: final key/value pair

Keys are nibbles derived from `keccak256` of the original key.

## Proof structure

An MPT proof is a list of encoded nodes from root to leaf. Verification:

1. Decode each node (RLP).
2. Traverse using the hashed key path.
3. Confirm the final value or non-inclusion marker.

HDP performs this verification twice:

- **Account proof** against the block `state_root`
- **Storage proof** against the account `storage_root`

## Non-inclusion proofs

If a key does not exist, MPT proofs return the empty value (`0x80`) for the requested slot. The verifier checks this condition explicitly.

## Implementation references

- `src/verifiers/evm/account_verifier.cairo`
- `src/verifiers/evm/storage_item_verifier.cairo`
- `crates/hints/src/verifiers/mpt.rs`
