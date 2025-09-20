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
- **Error Handling:** Uses `thiserror` with specific error types for detailed error reporting and debugging

## API Endpoints

### 1. Create Trie

Creates a new Merkle trie with initial key-value pairs.

**Endpoint:** `POST /create_trie`

**Request Body:**

```json
{
  "trie_label": "0x123",
  "keys": ["0x1", "0x2", "0x3"],
  "values": ["0x42", "0x84", "0x126"]
}
```

**Response:**

```json
{
  "trie_root": "0xabc123def456..."
}
```

**Example:**

```bash
curl -X POST http://localhost:3000/create_trie \
  -H "Content-Type: application/json" \
  -d '{
    "trie_label": "0x123",
    "keys": ["0x1", "0x2"],
    "values": ["0x42", "0x84"]
  }'
```

**Parameters:**

- `trie_label` (Felt): Unique identifier for the trie
- `keys` (Vec<Felt>): Array of keys to insert
- `values` (Vec<Felt>): Array of values corresponding to keys

**Returns:**

- `trie_root` (Felt): The root hash of the created trie

---

### 2. Read Key

Reads a value from a specific trie at a given root state.

**Endpoint:** `GET /read`

**Query Parameters:**

- `trie_label` (Felt): The trie identifier
- `trie_root` (Felt): The root hash of the trie state to read from
- `key` (Felt): The key to read

**Response:**

```json
{
  "key": "0x1",
  "value": "0x42"
}
```

**Example:**

```bash
curl "http://localhost:3000/read?trie_label=0x123&trie_root=0xabc123&key=0x1"
```

**Parameters:**

- `trie_label` (Felt): Unique identifier for the trie
- `trie_root` (Felt): Root hash of the trie state (use `0x0` for empty trie)
- `key` (Felt): Key to read

**Returns:**

- `key` (Felt): The requested key
- `value` (Option<Felt>): The value if key exists, `null` if not found

---

### 3. Write Key

Writes or updates a key-value pair in a trie, creating a new trie state.

**Endpoint:** `POST /write`

**Request Body:**

```json
{
  "trie_label": "0x123",
  "trie_root": "0xabc123",
  "key": "0x4",
  "value": "0x168"
}
```

**Response:**

```json
{
  "trie_id": 42,
  "trie_root": "0xdef456ghi789...",
  "key": "0x4",
  "value": "0x168"
}
```

**Example:**

```bash
curl -X POST http://localhost:3000/write \
  -H "Content-Type: application/json" \
  -d '{
    "trie_label": "0x123",
    "trie_root": "0xabc123",
    "key": "0x4",
    "value": "0x168"
  }'
```

**Parameters:**

- `trie_label` (Felt): Unique identifier for the trie
- `trie_root` (Felt): Current root hash (use `0x0` for empty trie)
- `key` (Felt): Key to write
- `value` (Felt): Value to write

**Returns:**

- `trie_id` (u64): Internal trie node index
- `trie_root` (Felt): New root hash after the write
- `key` (Felt): The written key
- `value` (Felt): The written value

---

### 4. Get State Proofs

Generates cryptographic proofs for read and write operations on tries.

**Endpoint:** `POST /get_state_proofs`

**Request Body:**

```json
{
  "actions": [
    {
      "Read": {
        "trie_label": "0x123",
        "trie_root": "0xabc123",
        "key": "0x1"
      }
    },
    {
      "Write": {
        "trie_label": "0x123",
        "trie_root": "0xabc123",
        "key": "0x4",
        "value": "0x168"
      }
    }
  ]
}
```

**Response:**

```json
{
  "state_proofs": [
    {
      "Read": {
        "trie_id": 42,
        "state_proof": ["0xnode1", "0xnode2", "0xnode3"],
        "trie_root": "0xabc123",
        "leaf": {
          "key": "0x1",
          "data": {
            "value": "0x42"
          }
        }
      }
    },
    {
      "Write": {
        "trie_id_prev": 42,
        "trie_root_prev": "0xabc123",
        "state_proof_prev": ["0xnode1", "0xnode2"],
        "leaf_prev": {
          "key": "0x4",
          "data": {
            "value": "0x0"
          }
        },
        "trie_id_post": 43,
        "trie_root_post": "0xdef456",
        "state_proof_post": ["0xnode1", "0xnode2", "0xnode4"],
        "leaf_post": {
          "key": "0x4",
          "data": {
            "value": "0x168"
          }
        }
      }
    }
  ]
}
```

**Example:**

```bash
curl -X POST http://localhost:3000/get_state_proofs \
  -H "Content-Type: application/json" \
  -d '{
    "actions": [
      {
        "Read": {
          "trie_label": "0x123",
          "trie_root": "0xabc123",
          "key": "0x1"
        }
      }
    ]
  }'
```

**Parameters:**

- `actions` (Vec<Action>): Array of read/write actions

**Action Types:**

- **Read Action:**

  - `trie_label` (Felt): Unique identifier for the trie
  - `trie_root` (Felt): Root hash of the trie state
  - `key` (Felt): Key to read

- **Write Action:**
  - `trie_label` (Felt): Unique identifier for the trie
  - `trie_root` (Felt): Current root hash
  - `key` (Felt): Key to write
  - `value` (Felt): Value to write

**Returns:**

- `state_proofs` (Vec<StateProof>): Array of cryptographic proofs

**Proof Types:**

- **Read Proof:** Inclusion/non-inclusion proof for a key
- **Write Proof:** Update proof showing state transition

---

### 5. Get Trie Root Node Index

Retrieves the internal node index for a given trie root hash.

**Endpoint:** `GET /get_trie_root_node_idx`

**Query Parameters:**

- `trie_label` (Felt): The trie identifier
- `trie_root` (Felt): The root hash to look up

**Response:**

```json
{
  "trie_root_node_idx": 42,
  "trie_root": "0xabc123"
}
```

**Example:**

```bash
curl "http://localhost:3000/get_trie_root_node_idx?trie_label=0x123&trie_root=0xabc123"
```

**Parameters:**

- `trie_label` (Felt): Unique identifier for the trie
- `trie_root` (Felt): Root hash to look up

**Returns:**

- `trie_root_node_idx` (u64): Internal node index (0 for zero root)
- `trie_root` (Felt): The requested root hash

**Error Responses:**

- `404 Not Found`: If the trie root doesn't exist in the database

---

## Usage with HDP Injected State

The state server integrates with HDP's injected state syscall handlers. The syscall handlers automatically interact with the state server API.

### Starting the Server

```bash
cargo run --bin state_server -- --port 3000
```

**Command Line Options:**

- `--port` (default: 3000): Port number to listen on
- `--host` (default: "0.0.0.0"): Host address to bind to
- `--db-root-path` (default: "db"): Path to the database root folder

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

## Data Types

### Felt

All keys, values, and identifiers use the `Felt` type, which represents a field element in the StarkNet field. Values can be provided as:

- Hexadecimal strings: `"0x123"`, `"0xabc"`
- Decimal strings: `"123"`, `"456"`
- Zero: `"0x0"` or `"0"`

### Trie Label

A unique identifier for each trie, allowing multiple independent tries to coexist. Each trie label gets its own SQLite database file.

### Root Hash

The Keccak256 hash of the trie root, representing a specific state of the trie. Each write operation creates a new root hash.

## Error Handling

The API returns appropriate HTTP status codes with detailed error messages:

- `200 OK`: Successful operations
- `400 Bad Request`: Invalid input (malformed JSON, missing parameters)
- `404 Not Found`: Resource not found (trie root, key, etc.)
- `500 Internal Server Error`: Server-side errors with specific error details

**Error Categories:**

The server provides specific error types for better debugging:

- **Database Errors**: SQLite query failures, connection pool issues
- **Crypto Errors**: Node encoding/decoding failures, hex parsing errors
- **Trie Errors**: Proof generation failures, RLP decoding errors
- **Storage Errors**: I/O operations, missing node indices

**Example Error Responses:**

```json
{
  "error": "MPT operation failed: Storage error: Database query failed: SQLITE_CONSTRAINT: UNIQUE constraint failed"
}
```

```json
{
  "error": "Resource not found"
}
```

## Security Considerations

- Run the state server in a secure environment
- Consider using authentication/authorization for production
- Database files are stored locally and should be backed up
- Network communication is unencrypted by default (use HTTPS in production)
- Each trie label is isolated in its own database file

## Performance Characteristics

- **Concurrent Access:** Multiple clients can safely access different tries simultaneously
- **Persistence:** All trie states are persisted to SQLite databases
- **Memory Usage:** Tries are loaded on-demand and cached in memory
- **Proof Generation:** Cryptographic proofs are generated efficiently using the underlying trie structure

## Building and Testing

```bash
# Build
cargo build --release

# Run tests
cargo nextest run

# Run with specific test
cargo nextest run --test api

# Run server in development
cargo run --bin state_server
```

## Example Workflows

### 1. Basic Trie Operations

```bash
# Create a new trie with initial data
curl -X POST http://localhost:3000/create_trie \
  -H "Content-Type: application/json" \
  -d '{
    "trie_label": "0x123",
    "keys": ["0x1", "0x2"],
    "values": ["0x42", "0x84"]
  }'

# Read a value
curl "http://localhost:3000/read?trie_label=0x123&trie_root=0xabc123&key=0x1"

# Write a new key-value pair
curl -X POST http://localhost:3000/write \
  -H "Content-Type: application/json" \
  -d '{
    "trie_label": "0x123",
    "trie_root": "0xabc123",
    "key": "0x3",
    "value": "0x126"
  }'
```

### 2. Proof Generation

```bash
# Generate read proof
curl -X POST http://localhost:3000/get_state_proofs \
  -H "Content-Type: application/json" \
  -d '{
    "actions": [
      {
        "Read": {
          "trie_label": "0x123",
          "trie_root": "0xabc123",
          "key": "0x1"
        }
      }
    ]
  }'

# Generate write proof
curl -X POST http://localhost:3000/get_state_proofs \
  -H "Content-Type: application/json" \
  -d '{
    "actions": [
      {
        "Write": {
          "trie_label": "0x123",
          "trie_root": "0xabc123",
          "key": "0x4",
          "value": "0x168"
        }
      }
    ]
  }'
```

### 3. Multiple Tries

```bash
# Create multiple independent tries
curl -X POST http://localhost:3000/create_trie \
  -H "Content-Type: application/json" \
  -d '{
    "trie_label": "0x111",
    "keys": ["0x1"],
    "values": ["0x100"]
  }'

curl -X POST http://localhost:3000/create_trie \
  -H "Content-Type: application/json" \
  -d '{
    "trie_label": "0x222",
    "keys": ["0x1"],
    "values": ["0x200"]
  }'

# Same key, different values in different tries
curl "http://localhost:3000/read?trie_label=0x111&trie_root=0xroot1&key=0x1"  # Returns 0x100
curl "http://localhost:3000/read?trie_label=0x222&trie_root=0xroot2&key=0x1"  # Returns 0x200
```

## Integration with HDP

The state server is designed to work seamlessly with HDP's injected state functionality. When HDP modules need to access external state, they can use the injected state syscalls which automatically communicate with the state server to:

1. Read values with cryptographic proofs
2. Write values with update proofs
3. Verify state transitions
4. Maintain state consistency across operations

This enables HDP modules to interact with external state in a cryptographically verifiable manner, making them suitable for use in zero-knowledge proof systems and other applications requiring state verification.
