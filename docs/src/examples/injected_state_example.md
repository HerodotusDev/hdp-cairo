# Injected State Example

This example demonstrates how to use injected state with a local state server.

## Location

`examples/injected_state/`

## Build

```bash
cd examples/injected_state
scarb build
```

## Run (source build)

The script starts the state server and runs the pipeline:

```bash
./run.sh
```

Key details:

- `state_server` runs in the background.
- `--injected_state examples/injected_state/injected_state.json` is passed to dry run and sound run.

## Run (CLI)

If you use the `hdp` binary, start the state server first:

```bash
cargo run --release --bin state_server
```

Then run the pipeline with `--injected_state` pointing to the JSON file.

If your state server runs on a non-default host/port, export `INJECTED_STATE_BASE_URL` before running the pipeline.
