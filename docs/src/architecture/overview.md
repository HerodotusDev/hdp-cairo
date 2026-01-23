# Architecture Overview

HDP Cairo is a layered system that combines Cairo0 verifiers, Cairo1 user modules, and Rust-based hint processors. The goal is to make historical blockchain data verifiable and deterministic.

## Layers

- **Cairo1 user layer**: your module uses the `hdp_cairo` library to request data.
- **Bootloader layer (Cairo0)**: loads the compiled Cairo1 class and executes it.
- **Verification layer (Cairo0)**: validates MMR/MPT/Patricia proofs before data is used.
- **Hint processors (Rust)**: bridge the Cairo VM with external data structures.
- **Orchestration (Rust)**: CLI commands for dry run, fetcher, and sound run.

## Data flow

```
+-----------+    +-----------+    +-----------+
| Dry Run   | -> | Fetcher   | -> | Sound Run |
| RPC keys  |    | Proofs    |    | Verify run|
+-----------+    +-----------+    +-----------+

dry_run_output.json -> proofs.json -> outputs
```

## Cairo0 vs Cairo1 boundary

- Cairo1 code calls `call_contract_syscall` via the `hdp_cairo` library.
- The Cairo VM forwards syscalls to the Rust `SyscallHandler`.
- The handler either performs RPC reads (dry run) or memorizer reads (sound run).

## Entry points

- `hdp dry-run`: stage 1, generates `dry_run_output.json`
- `hdp fetch-proofs`: stage 2, generates `proofs.json`
- `hdp sound-run`: stage 3, returns `task_hash`, `output_root`, and `mmr_metas`

