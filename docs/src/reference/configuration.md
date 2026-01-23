# Configuration

HDP reads configuration from environment variables. The CLI loads `.env` automatically via `dotenvy`.

## RPC endpoints

These variables are listed in `example.env`:

```bash
RPC_URL_ETHEREUM_MAINNET=
RPC_URL_ETHEREUM_TESTNET=
RPC_URL_OPTIMISM_MAINNET=
RPC_URL_OPTIMISM_TESTNET=
RPC_URL_STARKNET_MAINNET=
RPC_URL_STARKNET_TESTNET=
RPC_URL_HERODOTUS_INDEXER=https://rs-indexer.api.herodotus.cloud/
```

Injected state:

```bash
INJECTED_STATE_BASE_URL=http://localhost:3000
```

Set this explicitly when using injected state to avoid mismatched defaults between dry run and fetcher.

Use `hdp env-check --inputs dry_run_output.json` to see which RPCs are required for a given run.

Fetcher uses `RPC_URL_HERODOTUS_INDEXER` and `INJECTED_STATE_BASE_URL` when proofs are needed.

## Logging

Set the log level with either:

- `--log-level <LEVEL>` / `--debug`
- `RUST_LOG=<LEVEL>`

## Advanced

- `HDP_SOUND_RUN_PATH`: override the compiled sound-run program path
