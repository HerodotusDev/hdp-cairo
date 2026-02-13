# Debugging Guide

This page collects common troubleshooting steps for HDP pipelines and Cairo modules.

## Logging and verbosity

The CLI uses `tracing` and respects both flags and environment variables:

- `--log-level <trace|debug|info|warn|error>` sets the level explicitly.
- `--debug` is a shortcut for `--log-level debug`.
- `RUST_LOG=debug` works for all binaries (dry run, fetcher, sound run).

## Check your environment

Most failures in Stage 1 and Stage 2 are missing RPC endpoints. Use:

```bash
hdp env-info
hdp env-check --inputs dry_run_output.json
```

`env-check` inspects the dry run output and reports only the RPCs needed for that run.

## Inspect pipeline artifacts

- `dry_run_output.json` should contain key sets for EVM, Starknet, injected state, and unconstrained data.
- `proofs.json` should contain `chain_proofs`, `state_proofs`, and `unconstrained` sections.
- Use `--print_output` on dry run or sound run to print computed outputs.

If you suspect a mismatch, re-run the pipeline in order and make sure the compiled module and inputs have not changed between stages.

## Cairo module debugging

You can use `println!` inside Cairo1 contracts. To allow it during development, disable the validation pass:

```toml
[[target.starknet-contract]]
allowed-libfuncs-deny = true
```

```rust,ignore
#[starknet::contract]
mod contract {
    use hdp_cairo::HDP;

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        println!("Hello, world!");
    }
}
```

## Sound run is offline

Sound run does not hit the network. If you see missing data errors, confirm that:

- `proofs.json` was generated from the same `dry_run_output.json`.
- The proof file includes the chain you queried and the required proof types.

## Injected state issues

If injected state reads fail, confirm that `INJECTED_STATE_BASE_URL` points to the correct state server and that the server is running.

## Prover outputs

For proof-mode debugging:

- `sound-run --proof_mode` enables trace generation.
- `sound-run --cairo_pie <path>` writes a Cairo PIE zip.
- `sound-run --stwo_prover_input <path>` writes STWO inputs (requires `--features stwo`).
