# Multi-Chain Example

This example shows how to combine data from multiple chains in a single HDP module.

## Location

`examples/multi_chain_access/`

## Build

```bash
cd examples/multi_chain_access
scarb build
```

## Run (source build)

```bash
./run.sh
```

The script uses a custom MMR hasher config:

```bash
cargo run --bin fetcher -- --mmr-hasher-config examples/multi_chain_access/mmr_hasher_config.json
```

## Run (CLI)

```bash
hdp dry-run -m target/dev/example_multi_chain_access_module.compiled_contract_class.json --print_output
hdp fetch-proofs --mmr-hasher-config examples/multi_chain_access/mmr_hasher_config.json
hdp sound-run -m target/dev/example_multi_chain_access_module.compiled_contract_class.json --print_output
```
