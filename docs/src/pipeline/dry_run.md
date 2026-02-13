# Stage 1: Dry Run

The dry run simulates your Cairo module against live RPC data. It produces the key set that the fetcher later turns into proofs.

## Entry point

- `crates/dry_run/src/lib.rs`

## Execution flow

1. Load the compiled Cairo module.
2. Construct `HDPDryRunInput` (compiled class, params, injected state).
3. Run the Cairo VM with `CustomHintProcessor`.
4. Syscall handlers call RPC endpoints and collect keys.
5. Write `dry_run_output.json` with the serialized handler state.

The dry run uses the `all_cairo` layout in the Cairo VM.

## Output artifacts

- `dry_run_output.json`: serialized `SyscallHandler` containing key sets for each handler.
- Printed output (optional): `HDPDryRunOutput` with `task_hash` and `output_root` fields.

### `dry_run_output.json` structure (high level)

The file is a JSON serialization of the Rust `SyscallHandler`. At a high level it looks like:

```
{
  "call_contract_handler": {
    "evm_call_contract_handler": { "key_set": [ ... ] },
    "starknet_call_contract_handler": { "key_set": [ ... ] },
    "injected_state_call_contract_handler": { "key_set": { "<label>": [ ... ] } },
    "unconstrained_call_contract_handler": { "key_set": [ ... ] }
  }
}
```

This file is the only input needed by the fetcher.

If you pass `--print_output`, the command prints the decoded `HDPDryRunOutput` struct, which includes task hash and output root values.

### Requirements

Dry run requires RPC endpoints for any chain your module queries.

## CLI usage

```bash
hdp dry-run -m <module.compiled_contract_class.json> --print_output
```

Important flags:

- `--output <path>`: output path for `dry_run_output.json`
- `--inputs <path>`: JSON module input parameters
- `--injected_state <path>`: injected state JSON
- `--print_output`: prints the Cairo output segment
