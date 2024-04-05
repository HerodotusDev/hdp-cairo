# .::. Herodotus Data Processor EVM Interface .::.

## Introduction

These contracts serve as an interface for the full Herodotus Data Processor (HDP) process. The `HdpExecutionStore` contract allows you to trigger the process with a request method and authenticate the final task execution, storing valid results on-chain. To fully understand the HDP process, it is highly recommended to check the [documentation](https://docs.herodotus.dev/herodotus-docs/developers/herodotus-data-processor-hdp).

## Codecs

As all intermediate representations of the data lake and tasks should be encoded in bytes type, the HDP interface contract supports various data lakes and tasks to `encode`, `commit`, and `decode`.

### Datalake

-   [BlockSampledDatalakeCodecs](src/datatypes/BlockSampledDatalakeCodecs.sol)

### Task

-   [ComputationalTaskCodecs](src/datatypes/ComputationalTaskCodecs.sol)

## Getting Started

Pre-requisites:

-   Solidity (with solc >= 0.8.4)
-   Foundry

[HdpExecutionStore](src/HdpExecutionStore.sol) is the main contract.

## Deployment

Make sure to have a `.env` file configured with the variables defined in `.env.example`, then run:

```sh
source .env; forge script script/HdpExecutionStore.s.sol:HdpExecutionStoreDeployer --rpc-url $DEPLOY_RPC_URL --broadcast --verify -vvvv --via-ir
```

## Quick Start

```sh
# Navigate to hdp-evm
cd hdp-evm

# Install submodules
forge install

# Build contracts
forge build

# Test
forge test
```

## License

`hdp-evm` is licensed under the [GNU General Public License v3.0](./LICENSE).

---

Herodotus Dev Ltd - 2024
