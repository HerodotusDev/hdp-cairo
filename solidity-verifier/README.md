# .::. SHARP jobs solidity-verifier .::.

## Introduction

This Solidity verifier aggregates jobs (i.e., outputs from our Cairo program that serves as an EVM header off-chain accumulator) sent to the SHARP prover.

When the results are correctly verified, the global state of the contract is updated and reflects the new state.

The latest state of such a contract gives access to two Merkle Mountain Range (MMR) trees comprising the same elements but hashed with a different hash function (i.e., Poseidon and Keccak).

Considering that the two MMRs contain the same elements, the global `mmrSize` grows at the same rate for both trees.

## Aggregation types

The contract allows two kinds of aggregation:

-   Aggregating from the latest contract state (i.e., continuing proving backward in the genesis block direction)
-   Aggregating from a specific block number (i.e., continuing proving from an authenticated block)

Note: to continue aggregating from a higher block number than the current state, the higher block's parent hash must have been previously cached with the Solidity `blockhash()` global function by a call to `registerNewRange().`

## Aggregators & Factory

Aggregators are created through the `createAggregator()` function called by the `AggregatorsFactory` contract.

Each created aggregator can either start:

-   (i) From an initial blank state (i.e., two MMRs initialized with a single hashed element of value "brave new world" and a `mmrSize` of 1).
-   (ii) From an existing aggregator's state (i.e., two MMRs initialized with the same elements and `mmrSize` as the existing aggregator). This process is referred to as "detaching from an existing aggregator."

Note: when detaching from an existing aggregator, its aggregator ID must be specified and must have been created by the same factory contract.

### Aggregator Upgrades

The factory contract supports upgrades of the base aggregator contract to clone (i.e. `_template`).

It means that when `createAggregator()` is called, the aggregator contract is cloned from the latest version of the base aggregator contract that can be upgraded through an upgrade proposal and a three days delay before the upgrade is executable.

## Getting Started

Pre-requisites:

-   Solidity (with solc >= 0.8.0)
-   Foundry
-   Yarn
-   Node.js (>= v18.16.1)
-   (Optional) nvm use

[Here](src/SharpFactsAggregator.sol) is the main contract.

Note: the aggregation state is stored in the `SharpFactsAggregator` contract and can be retrieved by calling `getAggregatorState()`.

## Deployment

Make sure to have a `.env` file configured with the variables defined in `.env.example`, then run:

```sh
source .env; forge script script/AggregatorsFactory.s.sol:AggregatorsFactoryDeployer --rpc-url $DEPLOY_RPC_URL --broadcast --verify -vvvv
```

## Quick Start

```sh
# Navigate to solidity-verifier
cd solidity-verifier

# Install node_modules
yarn install

# (Optional) Switch node to v18.16.1 (or higher)
nvm use

# Install submodules
forge install

# Build contracts
forge build

# Test
forge test
```

Herodotus Dev - 2023
