---
name: Constrained Bytecode Implementation
overview: Implement constrained bytecode retrieval in Cairo0 with bytecode-to-code-hash verification. Bytecode will be stored in EVM memorizer keyed by code hash, replacing the current unconstrained approach. The implementation spans Cairo0, Cairo1, and Rust layers.
todos:
  - id: "1"
    content: Create Cairo0 bytecode hashing utility (src/utils/bytecode_hash.cairo) with verify_bytecode_hash and bytecode_le_words_to_u8_array function
    status: done
  - id: "2"
    content: Add bytecode key hashing to EVM memorizer (src/memorizers/evm/memorizer.cairo) - EvmPackParams.bytecode and EvmHashParams.bytecode
    status: pending
  - id: "3"
    content: Add BYTECODE to EvmStateAccessType and register in state_access.cairo
    status: pending
  - id: "4"
    content: Add bytecode_data input structure and bytecode_load_loop to src/hdp.cairo - verify BytecodeLeWords format, extract u8 array, and store in EVM memorizer
    status: pending
  - id: "5"
    content: Update Rust types (crates/types/src/lib.rs) to include bytecode in HDPInput
    status: pending
  - id: "6"
    content: Update dry run handler to fetch bytecode and record code hash key (crates/dry_hint_processor)
    status: pending
  - id: "7"
    content: Update sound run handler to read bytecode from EVM memorizer by code hash (crates/sound_hint_processor)
    status: pending
  - id: "8"
    content: Add bytecode syscall routing in execute_syscalls.cairo
    status: pending
  - id: "9"
    content: Add account_get_bytecode function to hdp_cairo/src/evm/account.cairo
    status: pending
  - id: "10"
    content: Update fetcher to collect bytecode data keyed by code hash (crates/fetcher/src/lib.rs)
    status: pending
  - id: "11"
    content: Add bytecode serialization hint for Cairo0 input loading (crates/hints)
    status: pending
  - id: "12"
    content: Create tests for bytecode functionality (tests/src/evm_modules/bytecode.cairo and .rs)
    status: pending
isProject: false
---

# Constrained Bytecode Implementation Plan

## Overview

This plan implements constrained bytecode retrieval where bytecode is verified against code hash in Cairo0 and stored in the EVM memorizer, accessible by code hash only. This replaces the current unconstrained bytecode approach.

## Architecture Flow

```
Dry Run → Fetch Bytecode from RPC → Add to HDPInput → Cairo0 Verification → Store in EVM Memorizer → Access by Code Hash
```

## Hint Language Usage

- **Rust Hints**: Used for Cairo1 code (in `hdp_cairo/`)
  - Dry run handlers: `crates/dry_hint_processor/src/syscall_handler/`
  - Sound run handlers: `crates/sound_hint_processor/src/syscall_handler/`
- **Python Hints**: Used for Cairo0 code (in `src/`)
  - Input loading: `crates/hints/src/contract_bootloader/params.rs`
  - Other Cairo0 hints: `crates/hints/src/`

## Existing Code to Reuse

1. **BytecodeLeWords Conversion**: `crates/types/src/cairo/unconstrained/bytecode.rs`

- `BytecodeLeWords::from(Bytes)` - converts raw bytes to BytecodeLeWords format
- `BytecodeLeWords::to_memory()` - serializes to Cairo memory
- Already used in unconstrained bytecode handling

1. **RPC Fetching**: `crates/fetcher/src/proof_keys/unconstrained.rs`

- `UnconstrainedProofKeys::fetch_bytecode(key)` - fetches bytecode from RPC
- Already handles RPC URL resolution and provider setup

1. **Dry Run Pattern**: `crates/dry_hint_processor/src/syscall_handler/unconstrained/mod.rs`

- Lines 66-70 show pattern for fetching bytecode and converting to BytecodeLeWords
- Can be adapted for EVM bytecode handler

## Implementation Steps

### Step 1: Create Cairo0 Bytecode Hashing Utility

**File**: `src/utils/bytecode_hash.cairo` (new file)

- Create a standalone function `verify_bytecode_hash` that:
  - Takes bytecode (as `ByteCodeLeWords` format) and expected code hash (as `Uint256`)
  - Computes keccak hash of bytecode using `cairo_keccak`
  - Reverses endianness to match EVM format
  - Compares with expected code hash
  - Returns success/failure or panics on mismatch
- Make it easily testable with minimal dependencies
- Reference implementation: `hdp_cairo/src/unconstrained/state.cairo:30-38`

**Key functions:**

- `verify_bytecode_hash{keccak_ptr: felt*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(bytecode_words: felt*, words_len: felt, lastInputWord: felt, lastInputNumBytes: felt, expected_hash: Uint256) -> ()`
- `bytecode_le_words_to_u8_array(bytecode_le_words_ptr: felt*) -> (u8_array: felt*, len: felt)` - Extracts u8 array from BytecodeLeWords format (used after verification for storage)

**Note**: We do NOT need `u8_array_to_bytecode_le_words` because:

- Rust side handles conversion from raw bytes to `BytecodeLeWords` format before passing to Cairo0
- After verification, we convert `BytecodeLeWords` to u8 array for storage
- When retrieving, memorizer returns u8 array directly (no conversion back needed)

### Step 2: Add Bytecode Get Function to EVM Memorizer (Cairo0)

**File**: `src/memorizers/evm/memorizer.cairo`

- Add new namespace `EvmPackParams.bytecode` that packs code hash (2 felts: high, low)
- Add `EvmHashParams.bytecode{poseidon_ptr: PoseidonBuiltin*}(code_hash: Uint256) -> felt` to hash code hash for memorizer key
- Add `EvmHashParams2.bytecode{poseidon_ptr: PoseidonBuiltin*}(params: felt*) -> felt` variant for syscall routing
- The key will be just the code hash (Poseidon hash of the 2-felt Uint256)
- **The value stored/retrieved is u8 array format**: array of felts `[byte0, byte1, byte2, ...]` where each felt = one byte/opcode
- `EvmMemorizer.get` for bytecode returns this u8 array directly (opcode-by-opcode form)

**File**: `src/memorizers/evm/state_access.cairo`

- Add `BYTECODE` to `EvmStateAccessType` enum
- Register bytecode hasher in `EvmStateAccess.init()`
- Add bytecode accessor function if needed (or reuse existing pattern)

### Step 3: Update HDPInput Structure and Processing

**File**: `src/hdp.cairo`

- Add new input section for bytecode data: `bytecode_data` (similar to `unconstrained`)
- Structure: array of `(code_hash_high, code_hash_low, bytecode_le_words_ptr)` tuples
  - `bytecode_le_words_ptr` points to `BytecodeLeWords` format in memory (for easy keccak hashing)
- Create `bytecode_load_loop` function that:
  - Iterates over bytecode entries
  - For each entry:
    - Extracts code hash (Uint256 from 2 felts)
    - Reads `BytecodeLeWords` from pointer (format: `words64bit_len, words64bit[], lastInputWord, lastInputNumBytes`)
    - Calls `verify_bytecode_hash` to verify bytecode matches code hash (using BytecodeLeWords format)
    - If match:
      - Extracts actual bytecode bytes from `BytecodeLeWords` using helper function `bytecode_le_words_to_u8_array`
      - Stores u8 array in EVM memorizer where each byte is stored as a felt252
      - Key: code hash (Poseidon hash of Uint256)
      - Value: array of felts `[byte0, byte1, byte2, ...]`, each representing one byte (opcode)
    - If mismatch: panics with error message
- Call this loop after unconstrained loading, before chain state verification

**Input structure in Python hint:**

```python
bytecode_data = [
    (code_hash_high, code_hash_low, bytecode_le_words_ptr),
    ...
]
# bytecode_le_words_ptr points to BytecodeLeWords serialized format
```

**Storage format in memorizer:**

- Key: Poseidon hash of code hash (2 felts: high, low)
- Value: Array of felts `[byte0, byte1, byte2, ...]` where each felt is one opcode/byte

### Step 4: Update Rust Types

**File**: `crates/types/src/lib.rs`

- Add `bytecode: HashMap<Uint256, Bytes>` to `HDPInput` struct (or create `BytecodeState` similar to `UnconstrainedState`)
- Update `HDPInput` deserialization to include bytecode data
- The key is `Uint256` (code hash), value is `Bytes` (raw bytecode)
- Note: The raw `Bytes` will be converted to `BytecodeLeWords` format when serializing to Cairo0 memory using existing `BytecodeLeWords::from(Bytes)` from `crates/types/src/cairo/unconstrained/bytecode.rs`

**File**: `crates/types/src/cairo/unconstrained/bytecode.rs` (reference existing)

- **REUSE**: `BytecodeLeWords::from(Bytes)` already exists and converts raw `Bytes` to `BytecodeLeWords` format
- This conversion is already used in unconstrained bytecode handling
- No new conversion function needed

### Step 5: Update Dry Run Handler (Rust - Rust Hints for Cairo1)

**File**: `crates/dry_hint_processor/src/syscall_handler/evm/mod.rs` or new file `bytecode.rs`

- Add new `CallHandlerId::Bytecode` variant
- When bytecode is requested in dry run:
  - Extract `AccountKey` from calldata (chain_id, block_number, address)
  - **REUSE**: Fetch bytecode from RPC using existing pattern from `crates/dry_hint_processor/src/syscall_handler/unconstrained/mod.rs:66-69`
  - **REUSE**: Convert to `BytecodeLeWords` using `BytecodeLeWords::from(bytes)` (already exists, see line 70 in unconstrained handler)
  - Fetch code hash from account (via existing account handler)
  - Record `DryRunKey::Bytecode(code_hash, account_key)` - key includes code hash
- Store both the bytecode and the code hash for later use
- **Note**: This uses Rust hints (for Cairo1 code in `hdp_cairo/`)

**File**: `crates/dry_hint_processor/src/syscall_handler/evm/mod.rs`

- Update `DryRunKey` enum to include `Bytecode(Uint256, keys::evm::account::Key)` where first param is code hash
- Update key recording logic

### Step 6: Update Sound Run Handler (Rust - Rust Hints for Cairo1)

**File**: `crates/sound_hint_processor/src/syscall_handler/evm/mod.rs` or new `bytecode.rs`

- Add handler for bytecode syscall
- When bytecode is requested:
  - Extract code hash from calldata (2 felts: high, low)
  - Read bytecode from EVM memorizer using code hash as key
  - **The EVM memorizer get_bytecode function returns u8 array format directly** (array of felts, each felt = one byte/opcode)
  - This is the opcode-by-opcode form stored in the memorizer
  - Return this u8 array format directly (no conversion needed)
- This replaces the unconstrained bytecode handler for EVM bytecode
- **Note**: This uses Rust hints (for Cairo1 code in `hdp_cairo/`)

### Step 7: Update Syscall Routing (Cairo0)

**File**: `src/contract_bootloader/execute_syscalls.cairo`

- Add new contract address or extend existing EVM contract address handling
- When bytecode selector is called:
  - Extract code hash from calldata (memorizer pointer + code_hash high/low)
  - Compute memorizer key using `EvmHashParams.bytecode`
  - Read from EVM memorizer using `EvmMemorizer.get`
  - **The EVM memorizer get function returns u8 array format directly** (array of felts, each felt = one byte/opcode)
  - This is the opcode-by-opcode form - what is stored and what is retrieved
  - Return the u8 array directly (no conversion needed)
- This should be accessible via contract address `1` (ACCOUNT) with a new selector

### Step 8: Update Cairo1 API

**File**: `hdp_cairo/src/evm/account.cairo`

- Add new function `account_get_bytecode(self: @EvmMemorizer, code_hash: u256) -> ByteCode`
- This function:
  - Calls `call_contract_syscall` with ACCOUNT contract, new BYTECODE selector
  - Passes code hash (high, low) in calldata
  - Receives u8 array format directly (array of felts, each felt = one byte/opcode)
  - Converts u8 array to `ByteCode` format (Span) for return
- Remove or deprecate the unconstrained bytecode access for EVM accounts

**File**: `hdp_cairo/src/lib.cairo`

- Ensure `ByteCode` and `ByteCodeLeWords` types are exported
- Update documentation

### Step 9: Update Fetcher

**File**: `crates/fetcher/src/lib.rs`

- Create `collect_bytecode_data` function (similar to `collect_unconstrained_data`)
- For each bytecode key from dry run:
  - **REUSE**: Fetch bytecode from RPC using `UnconstrainedProofKeys::fetch_bytecode(key)` from `crates/fetcher/src/proof_keys/unconstrained.rs:19-27`
  - Extract code hash from the key (first element of `DryRunKey::Bytecode(code_hash, account_key)`)
  - Store in `HDPInput.bytecode` map: `code_hash -> bytecode_bytes` (raw `Bytes`)
- The fetcher stores raw `Bytes` - conversion to `BytecodeLeWords` happens in hints when serializing to Cairo0 memory

**File**: `crates/fetcher/src/proof_keys/unconstrained.rs` (reference existing)

- **REUSE**: `UnconstrainedProofKeys::fetch_bytecode(key)` already exists and fetches bytecode from RPC
- No new RPC fetching code needed - reuse this existing function

### Step 10: Update Input Loading Hints (Python Hints for Cairo0)

**File**: `crates/hints/src/contract_bootloader/params.rs`

- Add Python hint function `hint_bytecode_data` (similar to `hint_unconstrained_data` at lines 156-179)
- **REUSE**: Use existing `BytecodeLeWords::from(Bytes)` conversion from `crates/types/src/cairo/unconstrained/bytecode.rs`
- **REUSE**: Use existing `BytecodeLeWords::to_memory()` method to serialize to Cairo memory
- Structure: `[(code_hash_high, code_hash_low, bytecode_le_words_ptr), ...]`
- The `bytecode_le_words_ptr` should point to serialized `BytecodeLeWords` in memory
  - Format: `words64bit_len, words64bit[], lastInputWord, lastInputNumBytes`
  - This format is used for keccak hashing verification in Cairo0
- **Note**: This uses Python hints (for Cairo0 code in `src/`)
- Reference the unconstrained loading pattern in `crates/hints/src/contract_bootloader/params.rs:156-179`
- Note: The actual bytecode bytes (u8 array) will be extracted from `BytecodeLeWords` in Cairo0 and stored in memorizer

### Step 11: Testing

**File**: `tests/src/evm_modules/bytecode.cairo` (new or update)

- Create test that:
  - Requests bytecode via new EVM memorizer API
  - Verifies bytecode matches expected code hash
  - Tests error case (mismatched code hash)
- Test the Cairo0 `verify_bytecode_hash` function independently

**File**: `tests/src/evm_modules/bytecode.rs` (new or update)

- Rust test driver for bytecode tests
- Test end-to-end: dry run → fetch → sound run → verify

### Step 12: Cleanup (Optional)

- Consider deprecating unconstrained bytecode for EVM accounts (keep for other use cases)
- Update documentation in `hdp_cairo/README.md`
- Update `REPO.md` with new bytecode flow

## Key Design Decisions

1. **Key Format**: Use code hash (Uint256) directly as the memorizer key (after Poseidon hashing for consistency)
2. **Input Format**: Rust converts raw bytecode to `BytecodeLeWords` format using existing `BytecodeLeWords::from(Bytes)` and passes to Cairo0 for easy keccak hashing
3. **Verification**: All bytecode is verified in Cairo0 during `hdp.cairo` execution using `BytecodeLeWords` format with keccak hashing, ensuring integrity
4. **Storage Format**: After verification, bytecode is converted from `BytecodeLeWords` to u8 array using `bytecode_le_words_to_u8_array` and stored in memorizer (each byte = one felt252)
5. **Retrieval Format**: **The EVM memorizer `get_bytecode` function returns the u8 array directly** (opcode-by-opcode form, each felt = one byte). This is what is stored and what is retrieved. No conversion back to `BytecodeLeWords` needed.
6. **Conversion Flow**: Rust → BytecodeLeWords → Cairo0 (verify) → u8 array (store) → u8 array (retrieve) → Cairo1 (convert to ByteCode if needed)
7. **Hint Languages**:

- **Rust hints** for Cairo1 code (in `hdp_cairo/`) - used in dry_run and sound_run handlers
- **Python hints** for Cairo0 code (in `src/`) - used in input loading hints

1. **Code Reuse**:

- Reuse `BytecodeLeWords::from(Bytes)` from `crates/types/src/cairo/unconstrained/bytecode.rs`
- Reuse `UnconstrainedProofKeys::fetch_bytecode()` from `crates/fetcher/src/proof_keys/unconstrained.rs`
- Reuse RPC fetching pattern from unconstrained bytecode handler

1. **Backward Compatibility**: Unconstrained bytecode remains for non-EVM use cases
2. **Error Handling**: Mismatched code hash causes panic in Cairo0, preventing invalid data

## Files to Create

- `src/utils/bytecode_hash.cairo` - Bytecode hashing and verification
- `tests/src/evm_modules/bytecode.cairo` - Cairo1 tests
- `tests/src/evm_modules/bytecode.rs` - Rust test driver
- `crates/dry_hint_processor/src/syscall_handler/evm/bytecode.rs` - Dry run handler (optional, can be in mod.rs)
- `crates/sound_hint_processor/src/syscall_handler/evm/bytecode.rs` - Sound run handler (optional)

## Files to Modify

- `src/memorizers/evm/memorizer.cairo` - Add bytecode key hashing
- `src/memorizers/evm/state_access.cairo` - Add bytecode access type
- `src/hdp.cairo` - Add bytecode loading and verification loop
- `src/contract_bootloader/execute_syscalls.cairo` - Add bytecode syscall routing
- `hdp_cairo/src/evm/account.cairo` - Add bytecode getter function
- `crates/types/src/lib.rs` - Add bytecode to HDPInput
- `crates/dry_hint_processor/src/syscall_handler/evm/mod.rs` - Add bytecode key recording
- `crates/sound_hint_processor/src/syscall_handler/evm/mod.rs` - Add bytecode handler
- `crates/fetcher/src/lib.rs` - Add bytecode collection
- `crates/hints/src/contract_bootloader/params.rs` - Add bytecode serialization hint

## Testing Strategy

1. **Unit Test**: Test `verify_bytecode_hash` with known bytecode/code hash pairs
2. **Integration Test**: Test full flow from dry run to sound run
3. **Error Test**: Test with mismatched code hash to ensure proper error handling
4. **Edge Cases**: Empty bytecode, large bytecode, various code hashes

# Plan preimage

## Simple Overview

- in cairo0 inputs we add codeHash -> bytecode mapping
- in hdp.cairo we constrain it - when loading inputs we check that every bytecode hashes to it's code hash, if not throw

## More in depth

- [Doneish] we add get bytecode function to evm memoizer
- when someone gets bytecode in dry run we get it from rpc and later add it to cairo0 inputs
- what we add to cairo0 inputs in src/hdp.cairo should be easy to iterate over all codeHashes and their bytecodes -> when iterating we need to hash every bytecode in cairo0 and check if it matches the codeHash, if it does we save it in the evm memoizer, available to get bytecode by codeHash, if it doesnt we throw error
- after src/hdp.cairo processing the inputs as explained above the bytecode should be easily gettable using the evm memoizer get bytecode function - by code hash - so the key for getting the bytecode should be code hash only.
- a component we definitely need for this to work is equivalent of hdp_cairo/src/unconstrained/state.cairo:30-38 - calculating the code hash in cairo0, this will need to be tested easily cause we will probably need to iterate many times to get to the correct hash, so a separate function taking the bytecode and codehash and trying to keccak the bytecode to get to the correct codehash and super easily runable and testable is needed
