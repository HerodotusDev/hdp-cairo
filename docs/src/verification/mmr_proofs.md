# MMR Proofs

Merkle Mountain Ranges (MMRs) provide an append-only commitment to block headers. They serve as the trusted anchor for historical data access.

## MMR basics

- An MMR is a set of perfect binary trees ("peaks") over an append-only sequence.
- Each peak root is hashed into a single commitment.
- Inclusion proofs show that a header hash appears at a given position.

## Hash functions

HDP supports two hashing modes:

- **Poseidon** (default for most chains)
- **Keccak** (used for specific deployments)

The fetcher can be configured per chain using `--mmr-hasher-config`.

## Verification steps

1. Validate the MMR meta (size, root, peak list).
2. Verify the header hash against the computed peak.
3. Use the verified header as the root of further proofs.

MMR metadata includes the `id`, `size`, `chain_id`, `root`, and peak list, along with the hashing function.

## Implementation references

- `src/verifiers/evm/header_verifier.cairo`
- `crates/hints/src/verifiers/evm/header_verifier.rs`
