# Rust-Cairo Integration

HDP uses the Cairo VM syscall interface to connect Cairo1 code to Rust logic. The same Cairo1 module runs in both dry run and sound run; only the Rust handlers change.

## Call flow

1. A Cairo1 module calls a method from `hdp_cairo`, which internally uses `call_contract_syscall`.
2. The Cairo VM forwards the syscall to the Rust `SyscallHandler`.
3. The handler decodes a `CallContractRequest`, routes it, and writes a `CallContractResponse`.
4. The result is decoded back in Cairo1 and returned to the caller.

## Syscall selectors

HDP handles two syscall selectors:

- `CallContract` for all data access paths.
- `Keccak` for Cairo keccak hashing.

The `Keccak` selector is handled by `KeccakHandler` inside the Rust `SyscallHandler`.

## Routing logic

The Rust `SyscallHandler` dispatches requests based on:

- **Contract address** for special handlers (debug, injected_state, unconstrained).
- **Chain ID** in calldata for EVM vs Starknet routing.

Relevant code paths:

- `crates/syscall_handler/src/lib.rs` (routing and execution)
- `crates/types/src/cairo/new_syscalls.rs` (request/response layout)
- `hdp_cairo/src/evm/*.cairo` and `hdp_cairo/src/starknet/*.cairo` (Cairo API)

## Dict manager and hints

The Cairo VM uses a shared `DictManager` for memorizers. During execution:

- Cairo hints can read/write dicts via the manager.
- Rust hint processors populate dicts during verification.

This is how verified data becomes available to Cairo1 calls without network access.

## Dry vs sound

- **Dry run** uses `dry_hint_processor` handlers that make RPC calls and collect keys.
- **Sound run** uses `sound_hint_processor` handlers that read from memorizers filled during verification.

This separation keeps Cairo code deterministic and identical across stages.
