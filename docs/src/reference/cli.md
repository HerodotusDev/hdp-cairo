# CLI Reference

The CLI binary is called `hdp` (built from the `hdp-cli` crate).

## Usage

```
hdp <command> [options]
```

## Commands

- `dry-run`: run Stage 1 and generate `dry_run_output.json`
- `fetch-proofs`: run Stage 2 and generate `proofs.json`
- `sound-run`: run Stage 3 and print outputs
- `program-hash`: compute program hash for a compiled Cairo program
- `env-info`: print expected environment variables
- `env-check`: check required RPC env vars for a dry run output
- `link`: symlink the `hdp_cairo` library into a project
- `update`: re-run the install script
- `pwd`: print the HDP repository path

## Common flags

- `--log-level <LEVEL>`: trace, debug, info, warn, error
- `--debug`: shortcut for `--log-level debug`

## dry-run

```
hdp dry-run --compiled_module <path> [--inputs <path>] [--injected_state <path>]
```

Options:

- `--program <path>` (`-p`): compiled dry-run program override
- `--compiled_module <path>` (`-m`): compiled Cairo1 module
- `--inputs <path>` (`-i`): JSON module input params
- `--injected_state <path>` (`-s`): injected state JSON
- `--output <path>` (`-o`): output path (default: `dry_run_output.json`)
- `--print_output`: print the Cairo output segment

## fetch-proofs

```
hdp fetch-proofs [--inputs dry_run_output.json] [--output proofs.json]
```

Options:

- `--inputs <path>` (`-i`): dry run output (default: `dry_run_output.json`)
- `--output <path>` (`-o`): output path (default: `proofs.json`)
- `--mmr-hasher-config <path>`: chain-specific hasher config
- `--mmr-deployment-config <path>`: chain deployment config

## sound-run

```
hdp sound-run --compiled_module <path> --proofs proofs.json
```

Options:

- `--program <path>` (`-p`): compiled sound-run program override
- `--compiled_module <path>` (`-m`): compiled Cairo1 module
- `--inputs <path>` (`-i`): JSON module input params
- `--injected_state <path>` (`-s`): injected state JSON
- `--print_output`: print the Cairo output segment
- `--proof_mode`: enable proof-mode execution
- `--cairo_pie <path>`: write a Cairo PIE zip
- `--stwo_prover_input <path>`: write STWO prover input (requires `--features stwo`)

## env-check

```
hdp env-check --inputs dry_run_output.json
```

## env-info

```
hdp env-info
```

Prints an example `.env` file and the variables required by HDP.

## program-hash

```
hdp program-hash [--program <path>]
```

Computes the program hash of a compiled Cairo program. If omitted, it uses the default HDP program.

## link

```
hdp link
```

Creates a `hdp_cairo` symlink in the current directory for local Scarb development.

## update

```
hdp update [--clean] [--local]
```

- `--clean`: clean build outputs before rebuilding.
- `--local`: build from the existing local repo without pulling from GitHub.

## pwd

```
hdp pwd
```

Prints the path to the HDP repository directory.
