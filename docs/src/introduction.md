# Introduction

HDP (Herodotus Data Processor) enables **provable computations on historical blockchain data**. It connects to live RPC nodes during a simulation phase, fetches cryptographic proofs for every accessed value, and replays the computation offline with verification guarantees.

## The problem

Historical on-chain data is hard to trust at scale. Indexers are fast but not verifiable, and replaying full chain history is too expensive for most applications. When you need to prove a statement about past state, you need both the data and a cryptographic trail that ties it back to a trusted root.

## The HDP approach

HDP splits execution into three stages:

1. **Dry run**: execute the Cairo module against live RPCs and collect the keys you touched.
2. **Fetcher**: download proofs for every key (MMR for headers, MPT/Patricia for state).
3. **Sound run**: verify proofs and execute the same Cairo module offline.

The result is deterministic output plus commitments (`task_hash`, `output_root`, and `mmr_metas`) that can be verified on-chain.

## Key capabilities

- **Cross-chain access**: Ethereum, Optimism, and Starknet in one module.
- **Cryptographic verification**: MMR for headers, MPT/Patricia for state.
- **Offline execution**: sound run has zero network calls.
- **Optional proof generation**: STWO prover input support.

## Use cases

- Solvency and reserve proofs
- Compliance and audit trails
- Historical analytics with provable results
- Cross-chain state composition

## Architecture at a glance

```
+------------------------+
| Cairo1 module          |
| uses hdp.* APIs        |
+------------------------+
| Cairo0 bootloader      |
| verifiers + outputs    |
+------------------------+
| Rust hints/handlers    |
| Dry: RPC keys          |
| Sound: memorizer reads |
+------------------------+
```

## How to read this book

Start with `Getting Started` to run a full pipeline. Then:

- `Architecture` for how the system fits together.
- `Pipeline` to understand each stage and its inputs/outputs.
- `Verification` and `State Management` for proof details.
- `Cairo Library` for the public API you use in modules.
- `Examples` and `Reference` for practical workflows and CLI details.
