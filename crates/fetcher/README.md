# Fetcher

A CLI tool that collects cryptographic proofs required for execution of HDP sound run stage. It consumes the output from the dry-run stage and fetches:
- EVM proofs: headers (with MMR metadata), accounts, storage, transaction receipts, transactions
- Starknet proofs: headers (with MMR metadata), storage
- Injected-state proofs via a running State Server


## Features

- Parse dry-run output and derive proof keys
- Concurrent proof collection with bounded concurrency
- Per-chain MMR hashing function:
  - Explicit via proof fetcher JSON config file
  - Auto-infer from Indexer accumulated ranges per chain endpoint (prefers Poseidon)
  - Fallback to Poseidon when unspecified
- Optional progress bars (feature flag)
- Emits a single JSON file combining ChainProofs and Injected State Proofs

Injected-state proofs are fetched over HTTP from a running State Server at URL specified in INJECTED_STATE_BASE_URL env variable

## CLI

Run with cargo:

```bash
cargo run --bin fetcher -- [OPTIONS]
```

Examples:
```bash
# With explicit per-chain hashing function config
cargo run --bin fetcher -- \
  --inputs dry_run_output.json \
  --output proofs.json \
  --proofs-fetcher-config proof_fetcher_config.json

# Auto-infer per-chain hashing function from Indexer ranges
cargo run --bin fetcher -- \
  --inputs dry_run_output.json \
  --output proofs.json

# Specify target chain
cargo run --bin fetcher -- \
  --inputs dry_run_output.json \
  --output proofs.json \
  --deployed-on-chain 10
```


### Providing explicit MMR hashing function per chain and the target chain

Create proof_fetcher_config.json:

```json
{
   "11155111": { "mmr_hashing_function": "poseidon" },
   "10":       { "mmr_hashing_function": "keccak" }
 }
```


```bash
cargo run --bin fetcher -- \
  --output proofs.json \
  --deployed-on-chain 11155111 \
  --proofs-fetcher-config proof_fetcher_config.json
```



## Output

The output is a single JSON file containing:
- A vector of ChainProofs (EVM and Starknet proofs, grouped per chain)
- A collection of injected-state proofs

