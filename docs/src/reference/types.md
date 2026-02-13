# Types Reference

This page summarizes the most important Rust and Cairo types used by HDP.

## Rust input/output types

| Type | Description | Location |
| --- | --- | --- |
| `HDPDryRunInput` | Compiled class, params, injected state | `crates/types/src/lib.rs` |
| `HDPInput` | Compiled class, params, proofs, injected state | `crates/types/src/lib.rs` |
| `ProofsData` | `chain_proofs`, `state_proofs`, `unconstrained` | `crates/types/src/lib.rs` |
| `HDPDryRunOutput` | Task hash and output root fields | `crates/types/src/lib.rs` |
| `HDPOutput` | Task hash, output root, `mmr_metas` | `crates/types/src/lib.rs` |
| `MmrMetaOutput` | Poseidon or Keccak MMR metadata | `crates/types/src/lib.rs` |
| `StateProofs` | Injected state proof list | `crates/types/src/proofs/injected_state/` |
| `InjectedState` | Initial injected state map | `crates/types/src/lib.rs` |
| `UnconstrainedState` | Unconstrained data map | `crates/types/src/lib.rs` |

## Chain identifiers

| Type | Description |
| --- | --- |
| `ChainIds` | Enum of supported chains |
| `ChainProofs` | Per-chain proof bundles |
| `HashingFunction` | Poseidon or Keccak |

`ProofsData` (the `proofs.json` file) is structured as:

```
{
  "chain_proofs": [ ... ],
  "state_proofs": [ ... ],
  "unconstrained": { ... }
}
```

`state_proofs` is ordered and can include both read and write proofs.

## Chain ID constants (Cairo)

The Cairo library exposes chain ID constants:

- `hdp_cairo::evm::{ETHEREUM_MAINNET_CHAIN_ID, ETHEREUM_TESTNET_CHAIN_ID, OPTIMISM_MAINNET_CHAIN_ID, OPTIMISM_TESTNET_CHAIN_ID}`
- `hdp_cairo::starknet::{STARKNET_MAINNET_CHAIN_ID, STARKNET_TESTNET_CHAIN_ID}`

## Dry run keys

Dry run handlers collect keys in a `DryRunKey` enum:

- `Header`, `Account`, `Storage`, `Tx`, `Receipt` for EVM
- Starknet keys are tracked in the Starknet handler

Source: `crates/dry_hint_processor/src/syscall_handler/`

Injected state and unconstrained handlers also define their own `DryRunKey` enums for state actions and bytecode.

## Cairo key structs

These are used when calling `hdp_cairo` APIs:

- EVM: `HeaderKey`, `AccountKey`, `StorageKey`, `BlockTxKey`, `BlockReceiptKey`, `LogKey`
- Starknet: `HeaderKey`, `StorageKey`

## Output fields

The sound run output segment is decoded as:

```
task_hash_low, task_hash_high, output_root_low, output_root_high,
poseidon_len, keccak_len,
poseidon_metas (4 felts each), keccak_metas (5 felts each)
```

`MmrMetaOutput` is encoded as:

- Poseidon: `id, size, chain_id, root`
- Keccak: `id, size, chain_id, root_low, root_high`
