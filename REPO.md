# HDP Cairo Repository - Architecture and Integration Guide

This document is the architecture source of truth for `hdp-cairo`. It consolidates the Cairo 0 bootloader, Cairo 1 module interface, and Rust hint/VM stack, and explains how features span all layers. It is based only on the repository code and docs.

## Table of Contents

1. Overview
2. Documentation Map
3. Repository Layout
4. Build and Tooling
5. Runtime Pipelines (Dry Run → Fetch Proofs → Sound Run)
6. Cairo 0 Layer (Bootloader, Verifiers, Memorizers)
7. Cairo 1 Layer (User Module API: `hdp_cairo`)
8. Rust Layer (Hints, Syscalls, Fetcher, CLI, State Server)
9. Cross-Layer Data Contracts (Calldata, Keys, Output Layout)
10. PR #230 Walkthrough: Unconstrained Bytecode End-to-End
11. Feature Addition Guide (Cross-Dependency Checklist)
12. Key File Index

---

## 1. Overview

HDP (Herodotus Data Processor) is a multi-layer system that:

- validates on-chain data via cryptographic proofs,
- executes user logic written in Cairo 1,
- and produces a trace suitable for proof generation.

The repo has three cooperating layers:

- **Cairo 0**: the bootloader, verifiers, memorizers, and decoders.
- **Cairo 1**: the `hdp_cairo` library used by user modules to access verified data via syscalls.
- **Rust**: the Cairo VM runtime, hint processors, syscall handlers, proof fetcher, and CLI.

The pipeline is explicitly staged:

1. **Dry Run**: simulate the Cairo 1 module and record required data keys.
2. **Fetch Proofs**: fetch proofs and data for all keys from RPCs and the state server.
3. **Sound Run**: verify proofs, populate memorizers, execute the module with verified data.

---

## 2. Documentation Map

Primary docs:

- `README.md`: installation and CLI usage, pipeline commands.
- `docs/src/introduction.md`: conceptual overview.
- `docs/src/architecture.md`: high-level architecture diagram.
- `docs/src/getting_started.md`: example module and CLI steps.
- `docs/src/debugging.md`: debugging with `println!`.

Module-specific docs:

- `hdp_cairo/README.md`: Cairo 1 usage examples (EVM and Starknet access).
- `crates/fetcher/README.md`: proof collection workflow and CLI flags.
- `crates/state_server/README.md`: injected state server API and syscall integration.
- `packages/eth_essentials/README.md`: Cairo 0 EVM utilities and `CAIRO_PATH`.

---

## 3. Repository Layout

Top-level structure:

- `src/`: Cairo 0 core (bootloader, verifiers, decoders, memorizers, utilities).
- `hdp_cairo/`: Cairo 1 interface crate used by user modules.
- `crates/`: Rust workspace (VM runtime, hints, syscalls, fetcher, CLI, state server).
- `tests/`: Cairo 1 + Rust tests (including unconstrained and injected state).
- `examples/`: sample Cairo 1 modules and run scripts.
- `docs/`: mdBook documentation with diagrams.
- `packages/eth_essentials/`: Cairo 0 submodule with EVM tooling and Cairo VM hints.

Workspaces:

- `Scarb.toml`: Cairo 1 workspace (examples, `hdp_cairo`, tests).
- `Cargo.toml`: Rust workspace (hint processors, fetcher, CLI, etc.).

---

## 4. Build and Tooling

### Cairo 1 Workspace (Scarb)

`Scarb.toml` defines members:

- `hdp_cairo` (library),
- `tests` (Cairo 1 tests),
- examples (`examples/*`).

### Rust Workspace (Cargo)

`Cargo.toml` defines crates including:

- `dry_run`, `sound_run`,
- `dry_hint_processor`, `sound_hint_processor`,
- `syscall_handler`, `types`, `fetcher`, `state_server`, `cli`,
- `hints` (central hint registry).

### Makefile

`Makefile` provides orchestrated setup/build/test:

- `make setup`: `uv sync`, `cargo check`.
- `make build`: `scarb build`, `cargo build --release`.
- `make test`: `scarb build -p tests`, `cargo nextest run`.

### Cairo 0 Dependencies

`packages/eth_essentials` is a Cairo 0 submodule; compilation requires `CAIRO_PATH` to include it.

---

## 5. Runtime Pipelines (Dry Run → Fetch Proofs → Sound Run)

### Dry Run

Entry: `crates/dry_run`.

Inputs:

- `HDPDryRunInput` (`types` crate): `{ params, compiled_class, injected_state }`.
- `compiled_class` is Cairo 1 CASM.

Flow:

- Runs `contract_dry_run.cairo`.
- Uses `CustomHintProcessor` (dry hint processor).
- Collects `SyscallHandler` containing key sets for EVM, Starknet, injected-state, and unconstrained.

Outputs:

- `SyscallHandler` serialized as JSON (the fetcher input).
- `HDPDryRunOutput` (task hash + output root).

### Fetch Proofs

Entry: `crates/fetcher`.

Inputs:

- `SyscallHandler` JSON from dry run.
- Optional configs: `mmr_hasher_config.json`, `mmr_deployment_config.json`.

Flow:

- Parses keys into `ProofKeys`.
- Fetches chain proofs (EVM, Starknet), injected-state proofs (state server), and unconstrained data (bytecode).

Output:

- `ProofsData` JSON with `{ chain_proofs, unconstrained, state_proofs }`.

### Sound Run

Entry: `crates/sound_run`.

Inputs:

- `HDPInput`: `{ params, compiled_class, injected_state, chain_proofs, state_proofs, unconstrained }`.
- `ProofsData` JSON from fetcher.

Flow:

- Runs `src/hdp.cairo`.
- Verifies proofs, populates memorizers, then executes the Cairo 1 module.

Output:

- `HDPOutput`: task hash, output root, and mixed MMR metadata.

---

## 6. Cairo 0 Layer (Bootloader, Verifiers, Memorizers)

### Main Programs

- `src/hdp.cairo`: sound-run entry. Loads `HDPInput`, verifies proofs, fills memorizers, runs Cairo 1 module, writes output.
- `src/contract_bootloader/contract_dry_run.cairo`: dry-run entry. Loads `HDPDryRunInput`, runs Cairo 1 module with dry run syscalls.

### Bootloader

`src/contract_bootloader/`:

- `contract.cairo`: builds calldata with memorizer pointers + module inputs, runs bootloader in sound mode.
- `contract_bootloader.cairo`: prepares builtins and runs `execute_entry_point`.
- `execute_entry_point.cairo`: runs module entrypoint and routes syscalls (skipped in dry run).
- `execute_syscalls.cairo`: core syscall routing (EVM/Starknet/injected-state/unconstrained).

### Verifiers

`src/verifiers/`:

- EVM: accounts, storage, receipts, transactions, headers, MMR.
- Starknet: headers, storage, MMR.
- Injected state: inclusion, non-inclusion, update proofs.

### Decoders

`src/decoders/`:

- EVM RLP decoding and extraction.
- Starknet header/storage decoding.

### Memorizers

`src/memorizers/`:

- `evm/`, `starknet/`, `injected_state/`, `unconstrained/`, `bare.cairo`.
- Memorizers are dictionaries storing verified data for fast access by syscalls.

---

## 7. Cairo 1 Layer (User Module API: `hdp_cairo`)

The `hdp_cairo` crate exposes the Cairo 1 interface used in user modules.

Key design:

- User modules receive an `HDP` struct that contains memorizer pointers.
- Module methods wrap `call_contract_syscall` to retrieve verified data.

Structure:

- `hdp_cairo/src/lib.cairo`: `HDP` struct and top-level exports.
- `hdp_cairo/src/evm/`: account, storage, header, transactions, receipts, etc.
- `hdp_cairo/src/starknet/`: Starknet header and storage access.
- `hdp_cairo/src/injected_state/`: injected-state accessors.
- `hdp_cairo/src/unconstrained/`: unconstrained bytecode access (PR #230).
- `hdp_cairo/src/eth_call/`: EVM call-related utilities.
- `hdp_cairo/src/arbitrary_type.cairo`: reserved syscall path for generic serialization.

Usage examples are in `hdp_cairo/README.md` and `docs/src/getting_started.md`.

---

## 8. Rust Layer (Hints, Syscalls, Fetcher, CLI, State Server)

### Hint Processors

- `crates/dry_hint_processor`: executes hints during dry run and records key access.
- `crates/sound_hint_processor`: executes hints during sound run and reads from memorizers.
- Both use `CustomHintProcessor` and a shared `SyscallHandlerWrapper`.

### Hint Registry

`crates/hints` defines:

- Cairo 0 bootloader hints (e.g., loading inputs, builtins).
- Verifier and decoder hints.
- Segment management hints.
- External hints from `eth_essentials_cairo_vm_hints`.

### Syscall Handlers

`crates/syscall_handler`:

- `CallContractHandlerRelay` routes by contract address or chain layout.
- Feature handlers:
  - `evm::CallContractHandler`
  - `starknet::CallContractHandler`
  - `injected_state::CallContractHandler`
  - `unconstrained::CallContractHandler`

### Fetcher

`crates/fetcher`:

- Parses the dry-run `SyscallHandler`.
- Fetches chain proofs and injected-state proofs.
- Fetches unconstrained bytecode and stores it in `ProofsData.unconstrained`.

### CLI

`crates/cli`:

- Commands: `dry-run`, `fetch-proofs`, `sound-run`, `program-hash`, `env-info`, `link`, `update`.
- Validates required env vars (e.g., `RPC_URL_HERODOTUS_INDEXER`).

### State Server

`crates/state_server`:

- Axum-based REST API for injected-state proofs and trie operations.
- Used by injected-state syscall handlers via `INJECTED_STATE_BASE_URL`.

---

## 9. Cross-Layer Data Contracts (Calldata, Keys, Output Layout)

### Calldata Layout for Module Execution

Both dry run and sound run use the same layout (see `contract.cairo` and `contract_dry_run.cairo`):

- `0..1`: EVM memorizer pointer (segment, offset)
- `2..3`: Starknet memorizer pointer
- `4..5`: Injected-state memorizer pointer
- `6..7`: Unconstrained memorizer pointer
- `8..`: module inputs (public + private inputs)

### Syscall Routing (Cairo 0)

`execute_syscalls.cairo` routes by contract address:

- `'debug'`: no-op
- `'arbitrary_type'`: no-op
- `'unconstrained'`: read from unconstrained memorizer
- `'injected_state'`: injected state ops based on selector
- otherwise: chain state access based on `chain_id` in calldata

### Key Hashing and Memorizer Access

Examples:

- `UnconstrainedHashParams.bytecode` hashes `(chain_id, block_number, address)` with Poseidon.
- Injected state uses Poseidon-hashed labels and per-action keys.

### Output Layout (Sound Run)

`types::HDPOutput` parses:

1. task hash (2 felts)
2. output root (2 felts)
3. mixed MMR metadata header `[poseidon_len, keccak_len]`
4. poseidon section: `poseidon_len * 4` felts
5. keccak section: `keccak_len * 5` felts

Dry run output (`HDPDryRunOutput`) contains only task hash + output root.

### Chain IDs

`crates/types` defines chain IDs and parsing helpers (Ethereum, Starknet, Optimism testnet/mainnet).

---

## 10. PR #230 Walkthrough: Unconstrained Bytecode End-to-End

PR #230 added the unconstrained bytecode module, which is the canonical example of a feature spanning all layers.

### Cairo 1 (User API)

`hdp_cairo/src/unconstrained/state.cairo`:

- `evm_account_get_bytecode` calls `call_contract_syscall` on contract address `'unconstrained'`, selector `0`.
- Deserializes `ByteCodeLeWords`, computes keccak, and validates against `evm.account_get_code_hash`.

### Cairo 0 (Bootloader + Memorizer)

- `src/memorizers/unconstrained/memorizer.cairo`:
  - defines key packing and Poseidon hashing
  - stores bytecode pointers
- `src/contract_bootloader/execute_syscalls.cairo`:
  - handles `'unconstrained'` contract address
  - extracts key parameters from calldata
  - reads from memorizer and returns data
- `src/hdp.cairo`:
  - loads `unconstrained` data from `HDPInput` into the memorizer

### Rust (Syscall Handlers + Fetcher)

- Dry run: `crates/dry_hint_processor/src/syscall_handler/unconstrained/mod.rs`
  - fetches bytecode from RPC and records `DryRunKey::Bytecode`.
- Sound run: `crates/sound_hint_processor/src/syscall_handler/unconstrained/mod.rs`
  - reads bytecode from memorizer using the hashed key.
- Fetcher: `crates/fetcher/src/lib.rs`
  - collects bytecode for keys into `ProofsData.unconstrained`.

### Tests

- `tests/src/unconstrained/bytecode.cairo` and `tests/src/unconstrained/bytecode.rs` drive validation.

This pattern is the canonical template for any new feature crossing Cairo 1, Cairo 0, and Rust.

---

## 11. Feature Addition Guide (Cross-Dependency Checklist)

Use this sequence for new features; PR #230 is the reference implementation.

### Step 1: Cairo 1 API

- Add a new module under `hdp_cairo/src/`.
- Use `call_contract_syscall` with a contract address and selector.
- Export from `hdp_cairo/src/lib.cairo` and add to `HDP` if needed.

### Step 2: Cairo 0 Memorizer

- Implement a new memorizer in `src/memorizers/<feature>/`.
- Define key packing + Poseidon hashing.
- Add load loops in `src/hdp.cairo` to populate the memorizer.

### Step 3: Cairo 0 Syscall Routing

- Add a routing branch in `src/contract_bootloader/execute_syscalls.cairo`:
  - match the contract address or selector
  - read from memorizer and write retdata

### Step 4: Rust Types

- Extend `crates/types` to include new data in `HDPInput` and `ProofsData`.
- Add new key types under `types::keys` if needed.

### Step 5: Rust Syscall Handlers

- Dry run handler in `crates/dry_hint_processor/src/syscall_handler/<feature>/`:
  - fetch data from RPC and record keys
- Sound run handler in `crates/sound_hint_processor/src/syscall_handler/<feature>/`:
  - read from memorizer and return data
- Register handlers in `crates/syscall_handler` relay.

### Step 6: Fetcher

- Parse new key types from dry-run `SyscallHandler`.
- Fetch required data/proofs and insert into `ProofsData`.

### Step 7: Hints (if input serialization is needed)

- If the feature requires new data serialized into Cairo memory, add hints in `crates/hints` and reference them from Cairo 0.

### Step 8: Tests and Examples

- Add Cairo 1 tests under `tests/src/<feature>/`.
- Add Rust test drivers if needed.
- Update examples if the feature is user-facing.

### Step 9: Docs

- Update `hdp_cairo/README.md` for API usage.
- Update `docs/src/architecture.md` or `docs/src/getting_started.md` if the feature affects onboarding.
- Update this `REPO.md` cross-dependency guide.

---

## 12. Key File Index

### Cairo 0

- `src/hdp.cairo`: sound-run orchestration and output writing.
- `src/contract_bootloader/contract.cairo`: calldata layout and bootloader invocation.
- `src/contract_bootloader/contract_dry_run.cairo`: dry-run entry.
- `src/contract_bootloader/execute_entry_point.cairo`: entrypoint execution and syscall dispatch.
- `src/contract_bootloader/execute_syscalls.cairo`: syscall routing.
- `src/memorizers/*`: verified data storage.
- `src/verifiers/*`: proof verification.
- `src/decoders/*`: data decoding.

### Cairo 1

- `hdp_cairo/src/lib.cairo`: `HDP` struct and exports.
- `hdp_cairo/src/evm/*`: EVM reads.
- `hdp_cairo/src/starknet/*`: Starknet reads.
- `hdp_cairo/src/injected_state/*`: injected-state reads/writes.
- `hdp_cairo/src/unconstrained/*`: unconstrained bytecode.
- `hdp_cairo/src/eth_call/*`: EVM call utilities.

### Rust

- `crates/dry_run`, `crates/sound_run`: runtime entry points.
- `crates/dry_hint_processor`, `crates/sound_hint_processor`: hint execution.
- `crates/hints`: hint registry and implementations.
- `crates/syscall_handler`: syscall routing and handler traits.
- `crates/fetcher`: proof collection.
- `crates/types`: shared types and output parsing.
- `crates/cli`: CLI entry points.
- `crates/state_server`: injected state server.

---

If you are adding or debugging a feature, follow the checklist in Section 11 and trace all layers in Section 9. The unconstrained bytecode module (PR #230) is the most complete cross-layer example in this repo.
