# Output Overview

HDP returns three core outputs after the sound run:

1. **task_hash**: unique identifier for the computation.
2. **output_root**: Merkle root for the computed results.
3. **mmr_metas**: MMR metadata for the headers used (id, size, chain, root).

These outputs are designed for on-chain verification and result extraction.

## Output layout

The Cairo output segment is serialized in this order:

```
task_hash_low
task_hash_high
output_root_low
output_root_high
poseidon_len
keccak_len
poseidon_metas (4 felts each)
keccak_metas (5 felts each)
```

Poseidon entries are `(id, size, chain_id, root)`. Keccak entries are `(id, size, chain_id, root_low, root_high)`.

## Where it is computed

- Task hash: `src/utils/utils.cairo`
- Output root: `src/utils/merkle.cairo`
- MMR metas: `src/utils/utils.cairo` and `src/hdp.cairo`
