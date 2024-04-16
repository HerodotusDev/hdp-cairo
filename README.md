# Cairo HDP

Cairo HDP is a set of Cairo0 programs that verify inclusion proofs and then runs computations on the data. This program can then be verified on-chain, enabling trustless computations on any historical data from Ethereum or integrated EVM chains.

## Installation and Setup

Install the required dependencies and setup Python virtual environment by running:

```bash
make setup
```

Make sure to run the cairo program from the virtual environment. To activate the virtual environment, run:

```bash
source venv/bin/activate
```

## Running

Before running the program, we need to make the program inputs available. The inputs are passed via the file `hdp_input.json` which is localed in the hdp root directory. The inputs can be generated with the [HDP CLI](https://github.com/HerodotusDev/hdp). Example inputs can be found in `tests/hdp/fixtures`.

Once the inputs are available, run the program by running:

```bash
make run-hdp
```

The program now output the results root and tasks root. These can then be used to extract the results from the on-chain contract.

## How it works

Cairo HDP essentially runs in three stages. In the first stage, all of the passed state is verified. Once the state is deemed valid, the program will run the defined tasks on the data. As the last step, the tasks and results are added to a merkle tree, returning the respective roots as output.

### 1. Verification

There are a number of different verification steps that can be run. Internally, they are run sequentially in the following order:

#### a: Header Verification

The first verification step is to verify the validity of the passed headers. This is done by recreating the MMR root, proving that every header is included in the MMR. Since the Herodotus header accumulator stores every Ethereum header, we can use it to verify the validity of the headers.

#### b: Account and Storage Slot Verification

The second verification step is to verify the validity of the passed account and storage slot data. This can be achieved by verifying MPT proofs, with the state_root from the respective header.

### 2. Computation

Currently, there are three different operators available. These are:

- `min`: Returns the minimum value of the passed data.
- `max`: Returns the maximum value of the passed data.
- `sum`: Returns the sum of the passed data.
- `avg`: Returns the average of the passed data.
- `count_if`: Returns the number of elements that satisfy a condition.

It must be noted, that these operations can be run on any field that we verified in the previous stage. This means its currently possible to run these aggregation functions on non-numerical values like addresses or hashes, e.g. `parent_hash` of a header.

### 3. Output Roots

As a last step, the results and tasks are added to a merkle tree. The roots of these trees are then returned as output. The results can then be extracted from the on-chain contract by providing the respective roots. This wil enable the generation of multiple aggregations in a single execution. The roots can then be used to extract the results on-chain.

## Adding a custom aggregation function

To add a new aggregation function, add it to `src/hdp/tasks/aggregate_functions`. Next, the function must then be integrated into the flow of datalake tasks handler. This will require an addition to the parameter decoder, and the execute fucntion. Currently only `BlockSampled` datalakes are used.

## Testing

Some tests reply on Ethereum Mainnet RPC calls. For this reason, an ENV variable name `RPC_URL_MAINNET` must be available.

To run (from VENV!):

```bash
make test-full
```

## Roadmap

Features that are planned or in progress:

### In Progress

**Transaction Verifier:** verifies and decodes raw transactions.

Status: ![](https://geps.dev/progress/65)

### Planned

**Merkelize:** extract data and add to merkle tree.

**Transaction Datalake:** a datalake focussed around transactions.

**Iterative Dynamic Layout Datalake:** iterate through a dynamic layout, e.g. a solidity mapping.

**Multi Task Executions:** run multiple tasks in a single execution.

**Bloom Filter Aggregate:** generate a bloom filter from the data.

Herodotus Dev Ltd - 2024.
