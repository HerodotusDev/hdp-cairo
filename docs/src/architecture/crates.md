# Rust Crates

This repository is organized into focused Rust crates. The most important ones are listed below.

| Crate | Purpose | Notes |
| --- | --- | --- |
| `cli` | User-facing CLI (`hdp`) | Subcommands: dry-run, fetch-proofs, sound-run |
| `dry_run` | Stage 1 execution | Runs Cairo VM with RPC-backed handlers |
| `fetcher` | Stage 2 proof collection | Builds `ProofsData` from key sets |
| `sound_run` | Stage 3 execution | Offline run with verified proofs |
| `dry_hint_processor` | Dry-run syscall handlers | RPC reads and key collection |
| `sound_hint_processor` | Sound-run syscall handlers | Reads from memorizers |
| `syscall_handler` | Shared syscall dispatch | Routes to EVM/Starknet/injected state |
| `hints` | Cairo hint implementations | 250+ hints for VM integration |
| `types` | Shared types and schemas | Inputs/outputs, keys, proofs |
| `indexer_client` | Herodotus Indexer API client | MMR proof requests |
| `state_server` | Injected state server | Patricia trie + proof API |

If you are new to the codebase, start with `cli`, `dry_run`, `fetcher`, and `sound_run`, then follow their dependencies.
