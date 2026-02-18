# HDP CLI (`hdp`)

This crate provides the `hdp` command-line tool for running HDP workflows, utility commands, and module upload to HDP server.

## Global Flags

All commands support:

- `--log-level <trace|debug|info|warn|error>`: set log level explicitly
- `--debug`: shorthand for `--log-level debug`

Examples:

```sh
hdp --debug dry-run -m target/dev/example_eth_call_module.compiled_contract_class.json
hdp --log-level trace fetch-proofs
```

## Command Reference

| Command | Purpose |
|---|---|
| `hdp dry-run` | Simulate module execution and produce dry-run output/preimage |
| `hdp fetch-proofs` | Fetch proof material required by HDP sound run |
| `hdp sound-run` | Execute verified run with fetched proofs |
| `hdp program-hash` | Print HDP program hash |
| `hdp upload` | Build and upload module package to HDP server |
| `hdp env-info` | Print example `.env` + runtime hints |
| `hdp link` | Symlink installed `hdp_cairo` into current project |
| `hdp update` | Reinstall/update CLI from installer script |
| `hdp pwd` | Print local HDP installation path |

---

## `hdp dry-run`

Runs dry simulation for a compiled Cairo module.

Common flags:

- `-m, --compiled_module <PATH>` (required)
- `-i, --inputs <PATH>` (optional params JSON)
- `-s, --injected_state <PATH>` (optional injected state JSON)
- `-o, --output <PATH>` (default: `dry_run_output.json`)
- `--output_preimage <PATH>` (default: `dry_run_output_preimage.json`)
- `--print_output`
- `--print_output_preimage`

Example:

```sh
hdp dry-run \
  -m target/dev/example_eth_call_module.compiled_contract_class.json \
  --print_output \
  --print_output_preimage
```

---

## `hdp fetch-proofs`

Fetches chain proofs using dry-run output.

Common flags:

- `-i, --inputs <PATH>` (default: `dry_run_output.json`)
- `-o, --output <PATH>` (default: `proofs.json`)
- `--mmr-hasher-config <PATH>` (optional)
- `--mmr-deployment-config <PATH>` (optional)

Example:

```sh
hdp fetch-proofs \
  -i dry_run_output.json \
  -o proofs.json \
  --mmr-deployment-config examples/eth_call/mmr_deployment_config.json
```

---

## `hdp sound-run`

Runs HDP program with fetched proofs and module.

Common flags:

- `-m, --compiled_module <PATH>` (required)
- `--proofs <PATH>` (default: `proofs.json`)
- `-i, --inputs <PATH>` (optional)
- `-s, --injected_state <PATH>` (optional)
- `--print_output`
- `--print_output_preimage`
- `--proof_mode`
- `--cairo_pie <PATH>`
- `--stwo_prover_input <PATH>` (requires `--proof_mode`)

Example:

```sh
hdp sound-run \
  -m target/dev/example_eth_call_module.compiled_contract_class.json \
  --proofs proofs.json \
  --print_output \
  --cairo_pie ./pie.zip
```

---

## `hdp program-hash`

Prints HDP program hash.

```sh
hdp program-hash
hdp program-hash -p /path/to/program.json
```

---

## `hdp upload`

Uploads a module package to HDP server. Must be run from a module root (contains `Scarb.toml`).

What it does:

1. Runs `scarb build`
2. Reads module metadata (`name`, `version`) from `Scarb.toml`
3. Finds generated `*.compiled_contract_class.json`
4. Collects all `src/**/*.cairo`
5. Uploads multipart payload to `POST /modules/upload`

Flags:

- `-k, --api-key <KEY>` (or `HERODOTUS_CLOUD_API_KEY`)
- `-u, --url <URL>` (or `HDP_SERVER_URL`, default `http://localhost:3001`)
- `--description <TEXT>`
- `--tags <CSV>`
- `--license <TEXT>`
- `--changelog <TEXT>`

Examples:

```sh
hdp upload --api-key "$HERODOTUS_CLOUD_API_KEY" --url "http://localhost:3001"
```

```sh
hdp upload \
  --api-key "$HERODOTUS_CLOUD_API_KEY" \
  --url "http://localhost:3001" \
  --description "Provable ETH call module" \
  --tags "eth_call,example" \
  --license "MIT" \
  --changelog "Initial upload"
```

---

## Utility Commands

### `hdp env-info`

Prints a ready-to-copy `.env` template and notes about RPC requirements.

```sh
hdp env-info
```

### `hdp link`

Creates `./hdp_cairo` symlink in current project to local installed HDP source (`~/.local/share/hdp`).

```sh
hdp link
```

### `hdp update`

Runs the installer script to update/reinstall CLI.

- `-c, --clean`: clean build path during update
- `-l, --local`: use local `install-cli.sh` instead of downloading from GitHub

```sh
hdp update
hdp update --clean
hdp update --local
```

### `hdp pwd`

Prints local HDP installation path.

```sh
hdp pwd
```

---

## Typical End-to-End Workflow

```sh
hdp dry-run -m target/dev/example_eth_call_module.compiled_contract_class.json --print_output
hdp fetch-proofs
hdp sound-run -m target/dev/example_eth_call_module.compiled_contract_class.json --print_output --cairo_pie ./pie.zip
```

If you hit env-related issues:

```sh
hdp env-info
```
