# Off-chain EVM Header Data Processor

![](.github/offchain-evm.png)

---

This repository contains three different components:

## 1. EVM Header MMR Accumulator

This direcotry implements the logic of building and maintaining two Merkle Mountain Ranges (MMRs) containing only provably valid Ethereum block headers.

Visualization of an MMR
![merkle mountain range tree](.github/mmr.png)

Building the MMRs happens off-chain and is proven using a Cairo program in the `src/single_chunk_processor` directory.
The CAIRO program takes as an input a blockhash passed by the verifier to then provide preimages to the given blockhash or a decoded parent hash that must be valid block headers.

Please read [src/single_chunk_processor/README.md](src/single_chunk_processor/README.md) for more details about the chunk processor.

The 2 MMRs store the same data and have the same size however are built with two different hash functions:

- Poseidon over the stark field
- Keccak256
  The values at the bottom of the MMR are keccak/poseidon hashes of the RLP encoded block headers.

The Starkware SHARP generates the proofs, and the proof verification happens on-chain.

## 2. Herodotus Data Processor

Cairo HDP is a tool enabling trustless computations on historical data from Ethereum or integrated EVM chains.

It exposes a varity of operators to perform computations on the data. The operators include `min`, `max`, `sum`, `avg`, `count_if`, and more. These operators can also be customized and extended.

A computatuions result can be verified on-chain in a fully trustless way. For ensuring valid EVM headers where used to generate the proofs, the tool uses the EVM Header MMR Accumulator.

Please read [src/hdp/README.md](src/hdp/README.md) for more details about HDP.

## 3. Libraries

This directory contains the Cairo libraries used by the Cairo programs in the `src` directory. These are shared between the chunk processor and HDP and are enable things like MPT verifications, RLP decoding, and more. 

## Additional data

### Max Resources per mainnet SHARP Job:

| Resource | Value      |
| -------- | ---------- |
| Steps    | 16,777,216 |
| RC       | 1,048,576  |
| Bitwise  | 262,144    |
| Keccaks  | 8,192      |
| Poseidon | 524,288    |

Herodotus Dev Ltd - 2024.
