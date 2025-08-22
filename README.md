# HDP Cairo

HDP (Herodotus Data Processor) is a modular framework for validating on-chain data from multiple blockchain RPC sources, executing user-defined logic written in Cairo1, and producing an execution trace that can be used to generate a zero-knowledge proof. The proof attests to the correctness of both the on-chain data and the performed computation.

---

<p align="center">
  <img src="./docs/HDPCairo.png" alt="HDP Cairo">
</p>

---

<p align="left">
  <a href="https://herodotusdev.github.io/hdp-cairo/program_hash.json">
    <img src="https://img.shields.io/badge/dynamic/json?url=https://herodotusdev.github.io/hdp-cairo/program_hash.json&query=$.program_hash&label=program_hash&color=blue&style=flat-square" alt="program_hash">
  </a>
</p>

---

## Installation

This project uses `uv` for Python package management and `cargo` for Rust.

### Prerequisites

1.  **Install Rust**: If you don't have Rust, install it via `rustup`.

    ```sh
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    ```

2.  **Install uv**: Install the `uv` Python package manager.

    ```sh
    curl -LsSf https://astral.sh/uv/install.sh | sh
    ```

### Build from Source

1.  **Clone the Repository**: Clone the repository and initialize the submodules.

    ```sh
    git submodule update --init
    ```

2.  **Create Virtual Environment**: This command creates a `.venv` directory and installs all Python packages specified in `pyproject.toml`.

    ```sh
    uv sync
    ```

3.  **Activate Virtual Environment**: To use tools like `cairo-format`, you need to activate the environment.

    ```sh
    source .venv/bin/activate
    ```

---

## Running

The runtime requires RPC calls to blockchain nodes. Ensure you create an environment variables file from the example and set the required values.

```sh
cp example.env .env
```

### Steps to Execute

1.  **Simulate Cairo1 Module & Collect Proof Information**:
    This step performs a dry run of your Cairo module. `module_contract_class.json` is a compiled contract from a Scarb build.

    ```sh
    cargo run --release --bin hdp-cli -- dry-run -m module_contract_class.json --print_output
    ```

2.  **Fetch On-Chain Proofs**:
    This command fetches the necessary on-chain proofs required for the HDP run.

    ```sh
    cargo run --release --bin hdp-cli --features progress_bars -- fetch-proofs
    ```

3.  **Run Cairo1 Module with Verified Data**:
    This executes the module with verified on-chain data.

    ```sh
    cargo run --release --bin hdp-cli -- sound-run -m module_contract_class.json --print_output
    ```

    The program will output the **results root** and **tasks root**, which can be used to extract the results from the on-chain contract.

---

## Testing

Tests also require chain node RPC calls, so make sure your `.env` file is set up correctly.

1.  **Build Cairo1 Modules**:

    ```sh
    scarb build
    ```

2.  **Run Tests**:
    Execute the test suite using `nextest`.

    ```sh
    cargo nextest run
    ```

---

## Note on On-Chain Finality

Even if all local stages (dry run, proof fetching, sound run) succeed, on-chain settlement depends on the **MMR (Merkle Mountain Range)**. The data for all accessed values must be present in the MMR core module used for settlement.

This means the blocks you are accessing must have been included in the settlement contract's MMR. This is a critical consideration, especially when mixing testnet and mainnet data or for cross-chain access within the same HDP module. If you encounter issues during on-chain settlement, verify that the relevant block numbers have been included in the on-chain MMR.
