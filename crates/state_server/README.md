# State Server

A RESTful API server for managing stateful Merkle tries, designed for use with HDP modules and other applications requiring cryptographically secure and persistent state management.

This server exposes endpoints to create, update, and query Merkle tries, leveraging a custom trie implementation with Keccak256 hashing and persistent storage, derived from the `trie-builder` crate that is using the `pathfinder-merkle-tree` crate.

## Features

- Create new Merkle tries with custom or auto-generated IDs
- Update tries with key-value pairs (hex or decimal)
- Retrieve root hashes of tries (Keccak256)
- Generate inclusion proofs for keys
- Access to multiple tries (via DashMap)
- Persistent storage using SQLite (via trie-builder and pathfinder-storage) and a custom implementation of the `TrieDB` trait.
- JSON API with robust error handling

## Implementation

- **Trie Engine:** Uses a custom trie implementation from `trie-builder` and `state-server-types`
- **Hashing:** All cryptographic operations use Keccak256 (via `pathfinder-crypto`)
- **Persistence:** Tries are stored in SQLite databases, one per trie
- **Concurrency:** `DashMap` enables safe concurrent access to all tries
- **API:** Built with Axum
- **Error Handling:** Uses `anyhow` and `thiserror` for robust error reporting

## Building

```bash
cargo build --release
```

## Running tests

```bash
cargo nextest run
```
