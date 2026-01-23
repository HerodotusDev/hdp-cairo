# Stage 2: Fetcher

The fetcher parses the key set from the dry run and downloads proofs from RPC endpoints and the Herodotus indexer.

## Entry point

- `crates/fetcher/src/lib.rs`

## Proof sources

- **Headers (MMR proofs)**: Herodotus Indexer
- **Accounts/Storage (MPT proofs)**: `eth_getProof` RPC calls
- **Transactions/Receipts**: MPT proofs built from RPC data
- **Injected state**: State server `get_state_proofs` endpoint
- **Unconstrained data**: bytecode values verified by code hash

## Output format

Fetcher outputs a `ProofsData` JSON file:

```
{
  "chain_proofs": [ ... ],
  "state_proofs": [ ... ],
  "unconstrained": { ... }
}
```

`chain_proofs` is a list of chain-specific proof bundles (`ChainProofs`).

Each bundle is one of:

- `EthereumMainnet` / `EthereumSepolia`
- `OptimismMainnet` / `OptimismSepolia`
- `StarknetMainnet` / `StarknetSepolia`

`state_proofs` is a list of injected state proofs (read/write).

### Inputs and environment

- `dry_run_output.json` is required (default input).
- `RPC_URL_HERODOTUS_INDEXER` must be set for MMR proofs.
- `INJECTED_STATE_BASE_URL` is used for injected state proofs.
- Chain RPC URLs (`RPC_URL_*`) are required for account/storage/tx/receipt proofs.

## CLI usage

```bash
hdp fetch-proofs --inputs dry_run_output.json --output proofs.json
```

Optional flags:

- `--mmr-hasher-config <path>`: configure Poseidon vs Keccak per chain
- `--mmr-deployment-config <path>`: override MMR deployment config
