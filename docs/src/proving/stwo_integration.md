# STWO Integration

HDP can emit STWO prover inputs during the sound run. This requires building the CLI with the `stwo` feature.

## Build with STWO

```bash
cargo +nightly build --release --bin hdp-cli --features stwo
```

## Generate prover input

```bash
hdp sound-run \
  -m <module.compiled_contract_class.json> \
  --proof_mode \
  --stwo_prover_input stwo_input.json
```

Notes:

- `--proof_mode` is required.
- If the binary was not built with `--features stwo`, HDP will fail with a clear error.
- The sound run uses the `all_cairo_stwo` layout internally.

Implementation: `crates/sound_run/src/prove.rs`
