# HDP CLI (`hdp`)

This crate provides the `hdp` command-line tool for running HDP workflows, utility commands, module upload, and direct task execution on HDP server.

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
| `hdp cloud upload` | Build and upload module package to HDP server |
| `hdp cloud execute` | Build module and submit `POST /tasks` with inline `compiled_class` |
| `hdp cloud list-modules` | List modules in a clean table (all or current user) |
| `hdp cloud module-versions` | List all versions of a given module in a clean table |
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

## `hdp cloud upload`

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
hdp cloud upload --api-key "$HERODOTUS_CLOUD_API_KEY" --url "http://localhost:3001"
```

```sh
hdp cloud upload \
  --api-key "$HERODOTUS_CLOUD_API_KEY" \
  --url "http://localhost:3001" \
  --description "Provable ETH call module" \
  --tags "eth_call,example" \
  --license "MIT" \
  --changelog "Initial upload"
```

Example output:

```text
2026-03-09T10:12:41.184222Z  INFO hdp_cli: 📦 Building module with Scarb...
2026-03-09T10:12:44.067981Z  INFO hdp_cli: ☁️ Uploading module to http://localhost:3778...
2026-03-09T10:12:44.512105Z  INFO hdp_cli: ✅ Module uploaded successfully!
🔗 Module page: https://herodotus.cloud/en/hdp/module/01KJW289R6EY49VSZZSEZ7S73V?program_hash=0x15863115785f401d87e161cb7d8be7b7a59a05a83bacaace78f7847faaed1d5

✅ Successfully uploaded module 'example_injected_state' v0.1.2
```

---

## `hdp cloud execute`

Builds the module and submits a task request directly to HDP server via `POST /tasks`.
This sends the compiled module JSON inline as `input.compiled_class` (no program-hash reference flow).

Flags:

- `-k, --api-key <KEY>` (or `HERODOTUS_CLOUD_API_KEY`)
- `-u, --url <URL>` (or `HDP_SERVER_URL`, default `http://localhost:3001`)
- `-d, --destination-chain-id <HEX>` (default `0xaa36a7`)
- `--params <JSON_ARRAY>` (default `[]`)
- `--injected-state <JSON_OBJECT>` (default `{}`)

Examples:

```sh
hdp cloud execute \
  --api-key "$HERODOTUS_CLOUD_API_KEY" \
  --url "http://localhost:3000" \
  --destination-chain-id "0xaa36a7"
```

```sh
hdp cloud execute \
  --api-key "$HERODOTUS_CLOUD_API_KEY" \
  --params '[]' \
  --injected-state '{}'
```

Example output:

```text
2026-03-09T10:15:29.095112Z  INFO hdp_cli: 🚀 Submitting task to http://localhost:3778...
🔗 Task page: https://herodotus.cloud/en/hdp/task/01KJWF2X8W51J6RMTN0V6P5W1M

✅ Task accepted: 01KJWF2X8W51J6RMTN0V6P5W1M
🔎 Check status:
   curl -H "X-API-KEY: <YOUR_API_KEY>" "http://localhost:3778/tasks/01KJWF2X8W51J6RMTN0V6P5W1M/status"
```

---

## `hdp cloud list-modules`

Lists modules as a clean terminal table.

Flags:

- `-u, --url <URL>` (or `HDP_SERVER_URL`, default `http://localhost:3001`)
- `--all` (list all modules)
- `-k, --api-key <KEY>` (or `HERODOTUS_CLOUD_API_KEY`; required when not using `--all`, calls `GET /modules/my`)

Examples:

```sh
hdp cloud list-modules --all
```

```sh
hdp cloud list-modules --api-key "$HERODOTUS_CLOUD_API_KEY"
```

Example output:

```text
2026-03-06T12:46:35.103690Z  INFO hdp_cli: 📦 Fetching modules from http://localhost:3778...

+----------------------------+------------------------+-------------------------------------------------------------------+----------------------------+-------------+
| MODULE_ID                  | NAME                   | LATEST_PROGRAM_HASH                                               | CREATOR_USER               | MARKETPLACE |
+----------------------------+------------------------+-------------------------------------------------------------------+----------------------------+-------------+
| 01KJW289R6EY49VSZZSEZ7S73V | example_injected_state | 0x15863115785f401d87e161cb7d8be7b7a59a05a83bacaace78f7847faaed1d5 | 01JMTKCQQ5MSCBEXAXWXNSRRGW | yes         |
+----------------------------+------------------------+-------------------------------------------------------------------+----------------------------+-------------+
```

---

## `hdp cloud module-versions`

Lists all versions for a module id as a clean terminal table.

Flags:

- `-m, --module-id <MODULE_ID>` (required)
- `-k, --api-key <KEY>` (optional; forwarded as `X-API-KEY` if provided)
- `-u, --url <URL>` (or `HDP_SERVER_URL`, default `http://localhost:3001`)

Example:

```sh
hdp cloud module-versions --module-id 01KABCDEF1234567890XYZ
```

```sh
hdp cloud module-versions \
  --module-id "01KJW289R6EY49VSZZSEZ7S73V" \
  --api-key "$HERODOTUS_CLOUD_API_KEY" \
  --url "http://localhost:3778"
```

Example output:

```text
2026-03-06T12:46:46.910061Z  INFO hdp_cli: 📚 Fetching module versions from http://localhost:3778...

+---------+-------------------------------------------------------------------+-------------+-----------------------------+
| VERSION | PROGRAM_HASH                                                      | USAGE_COUNT | CREATED_AT                  |
+---------+-------------------------------------------------------------------+-------------+-----------------------------+
| 0.1.2   | 0x15863115785f401d87e161cb7d8be7b7a59a05a83bacaace78f7847faaed1d5 | 0           | 2026-03-06T12:45:03.942680Z |
| 0.1.1   | 0x626bd504acfb3d3ddbafb093633eb479cc2d3e313491ed16e57c8d95829e01a | 0           | 2026-03-06T11:08:46.181758Z |
| 0.1.0   | 0x4d3da15a7f8dd517741e6879a323d16293d604f706eb9e5ec71953a96de1df2 | 0           | 2026-03-04T09:18:22.995019Z |
+---------+-------------------------------------------------------------------+-------------+-----------------------------+
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
