## Architecture

The HDP system is composed of several interlocking modules, each responsible for a specific part of the data processing pipeline.

### 1. Verifiers

- **Function:**  
  Validate on-chain data by checking the correctness of inclusion proofs (e.g., Merkle Patricia Trie for Ethereum) and confirming the presence of block headers.

- **Chain-Specific Implementation:**  
  Different verifiers exist for each supported blockchain (e.g., Ethereum, StarkNet) and the system is designed to be extended to support additional chains.

### 2. Memorizers

- **Function:**  
  Act as internal dictionaries to store verified and decoded data for later retrieval by the execution engine.

- **Usage:**  
  The bootloader retrieves data from these memorizers to ensure that the user-defined logic is executed on validated inputs.

### 3. Decoders

- **Function:**  
  Convert raw RPC data into formats that are usable by the user logic. This includes processes like RLP decoding or field element conversion.

- **Output:**  
  The decoded results are stored in the memorizers, ensuring quick and secure access during the execution phase.

### 4. Bootloader

- **Function:**  
  Serves as the execution engine that loads the user-defined Cairo1 bytecode, runs the logic, and manages the data flow from the memorizers.

- **Workflow:**
  - **Initialization:** Runs after the verifiers complete data validation and the memorizers are populated.
  - **Execution:** Runs the user’s logic using the verified data.
  - **Syscall Handling:** Invokes system calls (e.g., cryptographic hash functions provided by Cairo0) as required.
  - **Final Checks:** Validates the outputs of syscalls and ensures the integrity of the execution trace.

### 5. Proof computing

- **Purpose:**  
  After execution, the produced trace can be used in a zero-knowledge proving pipeline. The resulting proof attests that the data used was valid and that the user-defined logic was executed correctly.
