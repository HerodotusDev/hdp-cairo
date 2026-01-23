# StarkGate Solvency Example

This example compares StarkGate balances between Ethereum L1 and Starknet L2.

## Location

`examples/starkgate/`

## Build

```bash
cd examples/starkgate
scarb build
```

## Run (source build)

The example includes a script:

```bash
./run.sh
```

It performs:

- `dry_run` on `example_starkgate_module`
- `fetcher` to build `proofs.json`
- `sound_run` to verify and execute

## Run (CLI)

If you installed the `hdp` binary:

```bash
hdp dry-run -m target/dev/example_starkgate_module.compiled_contract_class.json --print_output
hdp fetch-proofs
hdp sound-run -m target/dev/example_starkgate_module.compiled_contract_class.json --print_output
```

## What to look for

The output prints the task hash, output root, and MMR metadata for the accessed headers.
