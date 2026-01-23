# Pipeline Overview

HDP executes in three stages to separate data discovery, proof fetching, and deterministic execution.

## Why three stages?

Historical data access requires cryptographic proofs that you can only fetch after you know which keys your module needs. The dry run discovers those keys, the fetcher collects the proofs, and the sound run replays the module with verified data.

## Execution flow

```
+-----------+    +-----------+    +-----------+
| Dry Run   | -> | Fetcher   | -> | Sound Run |
| RPC keys  |    | Proofs    |    | Verify run|
+-----------+    +-----------+    +-----------+

dry_run_output.json -> proofs.json -> outputs
```

## Inputs and outputs

- **Stage 1 output**: `dry_run_output.json` (serialized syscall handler with key sets)
- **Stage 2 output**: `proofs.json` (`ProofsData` with chain proofs and injected state proofs)
- **Stage 3 output**: `task_hash`, `output_root`, and `mmr_metas`

Each stage can be executed independently, which is helpful for debugging and caching.
