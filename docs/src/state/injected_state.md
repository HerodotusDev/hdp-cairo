# Injected State

Injected state is a custom, persistent state that can be read and updated across HDP runs. It is backed by a Patricia trie and served by the `state_server`.

## State server API

The state server exposes HTTP endpoints:

- `POST /create_trie` to initialize a trie label
- `POST /write` to update key/value pairs
- `GET /read` to read key/value pairs
- `GET /get_trie_root_node_idx` to fetch the current root
- `POST /get_state_proofs` to return Patricia proofs

Implementation: `crates/state_server/src/lib.rs`

The base URL is configured with `INJECTED_STATE_BASE_URL`.

Set this explicitly when using injected state; defaults differ between components.

## Running the state server

```bash
cargo run --release --bin state_server -- --host 0.0.0.0 --port 3000 --db_root_path db
```

## Cairo API

The Cairo1 interface lives in `hdp_cairo/src/injected_state/state.cairo`:

- `read_injected_state_trie_root(label)` -> `Option<felt252>`
- `read_key(label, key)` -> `Option<felt252>`
- `write_key(label, key, value)` -> updated trie root

## Proofs and verification

During the dry run, the handler records `ActionRead` and `ActionWrite` entries per trie label. The fetcher turns these actions into `StateProofs`, which are verified in Cairo0 by:

- `src/verifiers/injected_state/verify.cairo`

## Types

Injected state proofs are defined in `crates/types/src/proofs/injected_state/`:

- `ActionRead`, `ActionWrite` (dry-run actions)
- `StateProofRead`, `StateProofWrite` (proof payloads)

`state_proofs` is a list that mixes read and write proofs in execution order.

## Typical workflow

1. Provide an injected state JSON for dry run and sound run.
2. Fetch proofs from the state server during Stage 2.
3. Use `InjectedStateMemorizer` reads inside your module.
