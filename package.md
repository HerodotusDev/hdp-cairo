# hdp-cairo-dev

The `hdp-cairo-dev` Python package is an abstraction of all the necessary Python dependencies and supported custom module's Cairo 1.0 Sierra files. It provides a convenient way to set up a complete cairo-run environment that enables the execution of the [Herodotus Data Processor (HDP)](https://docs.herodotus.dev/herodotus-docs/developers/herodotus-data-processor-hdp).

To fully utilize the hdp-cairo-dev package and run HDP, two additional components are required:

1. Locate the compiled HDP Cairo program `hdp.json` in the directory where cairo-run is expected to be called from.
2. Install the `cairo1-run` Rust binary from the [`cario-vm/cairo1-run`](https://github.com/lambdaclass/cairo-vm/tree/main/cairo1-run) repository.

Herodotus Dev Ltd - 2024.
