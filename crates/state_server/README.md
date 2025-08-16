# State Server

A RESTful API server for managing stateful Merkle tries, designed for use with HDP modules and other applications requiring cryptographically secure and persistent state management.

This server exposes endpoints to create, update, and query Merkle tries, leveraging a custom trie implementation with Keccak256 hashing and persistent storage, derived from the `trie-builder` crate that is using the `pathfinder-merkle-tree` crate.

## Features

- Create new Merkle tries with custom or auto-generated IDs
- Update tries with key-value pairs (hex or decimal)
- Retrieve root hashes of tries (Keccak256)
- Generate inclusion/non-inclusion proofs for keys
- Generate update proofs for state changes
- Access to multiple tries (via DashMap)
- Persistent storage using SQLite
- JSON API with robust error handling
- Support for temporary mutations with proof generation

## Implementation

- **Trie Engine:** Uses a custom trie implementation from `trie-builder` and `state-server-types`
- **Hashing:** All cryptographic operations use Keccak256 (via `pathfinder-crypto`)
- **Persistence:** Tries are stored in SQLite databases, one per trie
- **Concurrency:** `DashMap` enables safe concurrent access to all tries
- **API:** Built with Axum
- **Error Handling:** Uses `anyhow` and `thiserror` for robust error reporting

## API Endpoints

### Create a New Trie

```bash
curl -X POST http://localhost:3000/new-trie \
  -H "Content-Type: application/json" \
  -d '{"id": "my_trie_id"}'
```

### Get Key Value

```bash
curl "http://localhost:3000/get-key/{trie_id}?key=<key>"
```

### Get Root Hash

```bash
curl http://localhost:3000/get-root-hash/{trie_id}
```

### Insert Initial Data

```bash
curl -X POST http://localhost:3000/insert-initial-data \
  -H "Content-Type: application/json" \
  -d '{
    "trie_id": "my_trie_id",
    "keys": ["0x1", "0x2"],
    "values": ["0x42", "0x84"]
  }'
```

### Get State Proofs

```bash
curl -X POST http://localhost:3000/get-state-proofs \
  -H "Content-Type: application/json" \
  -d '{
    "actions": [
      "trie_id;0;key",           # Read action (inclusion/non-inclusion proof)
      "trie_id;1;key;value"      # Write action (update proof)
    ]
  }'
```

## Usage with HDP Injected State

The state server integrates with HDP's injected state syscall handlers. The syscall handlers automatically interact with the state server API.

### Starting the Server

```bash
cargo run --bin state_server -- --port 3000
```

### Syscall Handler Integration

The injected state syscall handlers support three operations:

- **ReadKey** (`selector = 0`): Reads a value and generates inclusion/non-inclusion proof
- **UpsertKey** (`selector = 1`): Inserts/updates a key-value pair and generates update proof
- **DoesKeyExist** (`selector = 2`): Checks key existence
- **SetTreeRoot** (`selector = 3`): Sets the current tree root for state operations

### Configuration

```rust
use dry_hint_processor::syscall_handler::injected_state::CallContractHandler;

// Default: connects to http://localhost:3000
let handler = CallContractHandler::default();

// Custom configuration
let handler = CallContractHandler::new("http://my-state-server:8080")?;
```

## Error Handling

The API returns appropriate HTTP status codes:

- `200 OK`: Successful operations
- `400 Bad Request`: Invalid input
- `404 Not Found`: Trie/key not found
- `500 Internal Server Error`: Server-side errors

## Security Considerations

- Run the state server in a secure environment
- Consider using authentication/authorization for production
- Database files are stored locally and should be backed up
- Network communication is unencrypted by default (use HTTPS in production)

## Building and Testing

```bash
# Build
cargo build --release

# Run tests
cargo nextest run
```
