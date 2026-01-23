# Stage 3: Sound Run

Sound run verifies all proofs and executes your Cairo module **offline**. No RPC calls are performed in this stage.

## Entry point

- `crates/sound_run/src/lib.rs`

## Phases

1. **Verification**: Cairo0 verifiers check all proofs and populate memorizers.
2. **Execution**: the bootloader executes the Cairo1 module using the memorizers.
3. **Output**: compute `task_hash`, `output_root`, and `mmr_metas`.

Output composition happens in `src/hdp.cairo`, which writes the output segment in a fixed layout.

The sound run config uses the `all_cairo_stwo` layout, and `--proof_mode` toggles proof-oriented tracing.

## Outputs

The Cairo output segment is decoded into `HDPOutput`:

- `task_hash_low` / `task_hash_high`
- `output_tree_root_low` / `output_tree_root_high`
- `mmr_metas` (Poseidon or Keccak variants)

See `docs/output/overview.md` for the exact output layout.

The sound run assumes that `proofs.json` was generated from the matching `dry_run_output.json` for the same compiled module and inputs.

## CLI usage

```bash
hdp sound-run -m <module.compiled_contract_class.json> --proofs proofs.json --print_output
```

## Proof-mode options

Sound run can emit prover artifacts:

- `--proof_mode`: enable proof-mode execution
- `--cairo_pie <path>`: write Cairo PIE zip
- `--stwo_prover_input <path>`: write STWO prover input (requires `--features stwo`)
