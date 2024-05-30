# hdp-cairo-dev

The `hdp-cairo-dev` Python package abstracts all necessary Python dependencies and supported custom modules for Cairo1 Sierra files. It provides a convenient setup for a complete cairo-run environment, enabling the execution of the [Herodotus Data Processor (HDP)](https://docs.herodotus.dev/herodotus-docs/developers/herodotus-data-processor-hdp).

To fully utilize the `hdp-cairo-dev` package and run HDP, two additional components are required:

1. **Locate the Compiled HDP Cairo Program**: Ensure the `hdp.json` file is in the directory from which cairo-run is expected to be executed.
2. **Install the `cairo1-run` Rust Binary**: Obtain this from the [`cairo-vm/cairo1-run`](https://github.com/lambdaclass/cairo-vm/tree/main/cairo1-run) repository.

### Package Components:

- **Tools**: This package includes class definitions and functionalities for fetching `Blocks` and `Transactions`, along with a set of utilities for developers.
- **hdp_bootloader**: A fine-tuned implementation of the Cairo0 bootloader for HDP, enabling dynamic loading of Cairo1 bytecode modules. This allows for the definition of aggregate functions in the Cairo1 language.
- **Compiled Cairo 1 Modules**: A set of compiled Cairo 1 modules used as aggregate functions within the HDP function set.

---

Herodotus Dev Ltd - 2024