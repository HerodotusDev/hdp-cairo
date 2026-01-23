# Syscall Handlers Overview

Syscall handlers are the Rust side of the Cairo VM syscall interface. They decode `CallContract` requests and return the data your Cairo module expects.

## Core types

- `CallContractRequest` and `CallContractResponse` define the memory layout.
- `SyscallHandler` owns the routing logic and per-chain handlers.
- `CallHandler` in `crates/syscall_handler/src/traits.rs` defines the handler interface.

## Keccak syscall

The `Keccak` syscall selector is handled by `KeccakHandler`, which exposes Cairo keccak hashing to the VM.

Relevant code:

- `crates/syscall_handler/src/lib.rs`
- `crates/types/src/cairo/new_syscalls.rs`

## Routing behavior

The handler inspects the `contract_address` and calldata:

- Special handlers: `'debug'`, `'arbitrary_type'`, `'injected_state'`, `'unconstrained'`
- All other calls use the chain ID encoded in calldata to select EVM vs Starknet handlers.

The EVM and Starknet handlers use separate internal `CallHandlerId` enums to select header vs storage vs receipt logic.

### EVM call handler IDs

When routing to the EVM handler, the numeric `contract_address` selects the call handler:

- `0`: header
- `1`: account
- `2`: storage
- `3`: transaction
- `4`: receipt
- `5`: log

## Handler state

Handlers store:

- **Dry run**: key sets (`HashSet<DryRunKey>`) used by the fetcher.
- **Sound run**: memorizer references for verified data.
