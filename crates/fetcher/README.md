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
  --mmr-hasher-config mmr_hasher_config.json

# Auto-infer per-chain hashing function from Indexer ranges
cargo run --bin fetcher -- \
  --inputs dry_run_output.json \
  --output proofs.json

# Specify target chains for each source chain
cargo run --bin fetcher -- \
  --inputs dry_run_output.json \
  --output proofs.json \
  --mmr-deployment-config mmr_deployment_config.json
```


### Providing explicit MMR hashing function per chain and the target chain

Create mmr_hasher_config.json

```json
{
  "11155111": "keccak",
  "11155420": "poseidon",
  "10": "keccak",
  "393402133025997798000961": "poseidon"
}
```

### Providing the MMR destination chain for specific proof source chain

Create mmr_deployment_config.json:

```json
{
   "11155111": 11155222,
   "393402133025997798000961": 393402133025997798000961 , // Startnet Sepolia as source and destination chain
   "10": 480  // Optimism Mainnet as source chain and Worldchain Mainnet as destination chain
 }
```



```bash
cargo run --bin fetcher -- \
  --output proofs.json \
  --mmr-hasher-config mmr_hasher_config.json \
  --mmr-deployment-config mmr_deployment_config.json
```



## Output

The output is a single JSON file containing:
- A vector of ChainProofs (EVM and Starknet proofs, grouped per chain)
- A collection of injected-state proofs

