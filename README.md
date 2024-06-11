# Cairo HDP

Cairo HDP is a collection of Cairo0 programs designed to verify inclusion proofs and perform computations on the data. These computations can be verified on-chain, enabling trustless operations on any historical data from Ethereum or integrated EVM chains.

## Run docker test run
```bash
docker build -t hdp-cairo . && docker run hdp-cairo
```

## Installation and Setup

To install the required dependencies and set up the Python virtual environment, run:

```bash
make setup
```

Ensure you run the Cairo program from the virtual environment. To activate the virtual environment, execute:

```bash
source venv/bin/activate
```

## Running

Before running the program, prepare the input data. The inputs are provided via the `hdp_input.json` file located in the root directory of the HDP project. These inputs can be generated using the [HDP CLI](https://github.com/HerodotusDev/hdp). Example inputs are available in `tests/hdp/fixtures`.

To run the program, use:

```bash
make run-hdp
```

The program will output the results root and tasks root. These roots can be used to extract the results from the on-chain contract.

## How It Works

Cairo HDP operates in three main stages. First, it verifies the passed state. Upon validation, it executes the defined tasks on the data. Finally, the tasks and results are added to a Merkle tree, returning the respective roots as output.

### 1. Verification

Verification involves several sequential steps:

#### a: Header Verification

The first step is to verify the validity of the passed headers by recreating the MMR root, proving each header's inclusion in the MMR. Since the Herodotus header accumulator stores every Ethereum header, it verifies the headers' validity.

#### b: Account and Storage Slot Verification

The second step is to verify the passed account and storage slot data's validity by checking MPT proofs against the state root from the respective header.

### 2. Computation

Currently, the following operators are available:

- `min`: Returns the minimum value of the passed data.
- `max`: Returns the maximum value of the passed data.
- `sum`: Returns the sum of the passed data.
- `avg`: Returns the average of the passed data.
- `count_if`: Returns the number of elements that satisfy a condition.
- `slr`: Returns the best-fit linear regression predicted point for the supplied data.

These operations can be performed on any verified field, including non-numerical values like addresses or hashes, such as the `parent_hash` of a header.

### 3. Output Roots

In the final step, the results and tasks are added to a Merkle tree, and the roots of these trees are returned as output. These roots can be used to extract the results from the on-chain contract, enabling multiple aggregations in a single execution.

## Adding a Custom Aggregation Function

To add a new aggregation function:

1. Add the function to `src/tasks/aggregate_functions`.
2. Integrate the function into the datalake tasks handler by updating the parameter decoder and the `execute` function.
3. Define the `fetch_trait` function for this aggregation functionality.

## Adding a Custom Cairo1 Module

HDP can dynamically load Cairo1 programs at runtime, allowing the creation of Cairo1 modules with aggregate function logic. To add a Cairo1 module:

1. Create a new Scarb project in `src/cairo1/`.
2. Add the new aggregation function file to `src/tasks/aggregate_functions`.
3. Define the `fetch_trait` function appropriate for this aggregation functionality.

## Fetch Trait

The `fetch_trait` is an abstract template containing datalake-specific data fetching functions. Each aggregate function must implement this template individually.

## Testing

Some tests require Ethereum Mainnet RPC calls. Ensure an environment variable named `RPC_URL_MAINNET` is set.

To run the tests (from the virtual environment), execute:

```bash
make test-full
```

## Roadmap

### In Progress

- **Transaction Verifier:** Verifies and decodes raw transactions.
  - Status: ![](https://geps.dev/progress/65)

### Planned

- **Merkelize:** Extract data and add it to a Merkle tree.
- **Transaction Datalake:** A datalake focused on transactions.
- **Iterative Dynamic Layout Datalake:** Iterate through a dynamic layout, such as a Solidity mapping.
- **Multi Task Executions:** Run multiple tasks in a single execution.
- **Bloom Filter Aggregate:** Generate a bloom filter from the data.

Herodotus Dev Ltd - 2024

---