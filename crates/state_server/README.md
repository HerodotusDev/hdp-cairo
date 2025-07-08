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

## API Endpoints

### Create a New Trie

```bash
curl -X POST http://localhost:3000/new-trie \
  -H "Content-Type: application/json" \
  -d '{"id": "my_trie_id"}'
```

### Update a Trie

```bash
curl -X POST http://localhost:3000/update-trie/my_trie_id \
  -H "Content-Type: application/json" \
  -d '{"key": "0x1", "value": "0x42"}'
```

### Get Root Hash

```bash
curl http://localhost:3000/get-root-hash/my_trie_id
```

### Get Proof (Check if key exists and get value)

```bash
curl "http://localhost:3000/get-proof/my_trie_id?key=0x1"
```

## Usage with HDP Injected State

The state server is designed to work with HDP's injected state syscall handlers. When using the `dry_hint_processor` or `sound_hint_processor`, the syscall handlers will automatically interact with the state server API.

### Starting the State Server

```bash
# Start the state server on port 3000
cargo run --bin state_server -- --port 3000
```

### Syscall Handler Integration

The injected state syscall handlers (`CallContractHandler`) automatically:

1. **Create trie on first use**: When the handler is initialized, it creates a trie with a unique ID:

   - `dry_hint_processor`: Uses trie ID `"injected_state_trie_dry"`
   - `sound_hint_processor`: Uses trie ID `"injected_state_trie_sound"`

2. **Handle three operations**:
   - **ReadKey** (`selector = 0`): Reads a value from the trie
   - **UpsertKey** (`selector = 1`): Inserts or updates a key-value pair
   - **DoesKeyExist** (`selector = 2`): Checks if a key exists

### Configuration

The syscall handlers can be configured to use different state server URLs:

```rust
use dry_hint_processor::syscall_handler::injected_state::CallContractHandler;

// Default: connects to http://localhost:3000
let handler = CallContractHandler::default();

// Custom configuration
let handler = CallContractHandler::new(
    "http://my-state-server:8080",  // Custom URL
    "my_custom_trie_id"             // Custom trie ID
)?;
```

### Example Usage Flow

1. **Start the state server**:

   ```bash
   cargo run --bin state_server -- --port 3000
   ```

2. **Run HDP program** with injected state syscalls:

   ```bash
   # The syscall handlers will automatically:
   # 1. Create a trie (POST /new-trie)
   # 2. Handle read/write operations via API calls
   # 3. Persist all state changes in the server
   ```

3. **Query state directly** (optional):
   ```bash
   curl "http://localhost:3000/get-proof/injected_state_trie_dry?key=my_key"
   ```

## Building

```bash
cargo build --release
```

## Running tests

```bash
cargo nextest run
```

## Error Handling

The API returns appropriate HTTP status codes:

- `200 OK`: Successful operations
- `400 Bad Request`: Invalid input (e.g., malformed keys)
- `404 Not Found`: Trie not found
- `409 Conflict`: Trie already exists (when creating)
- `500 Internal Server Error`: Server-side errors

## Security Considerations

- The state server should be run in a secure environment
- Consider using authentication/authorization for production deployments
- Database files are stored locally and should be backed up appropriately
- Network communication is unencrypted by default (consider using HTTPS in production)
