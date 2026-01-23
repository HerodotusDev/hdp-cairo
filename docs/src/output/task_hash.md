# Task Hash

The task hash uniquely identifies an HDP computation. It matches the Solidity encoding used by the Satellite contracts.

## Formula

```
task_hash = keccak(
    module_hash ||
    0x40 ||
    public_inputs_len ||
    public_inputs
)
```

`0x40` is the Solidity dynamic array offset (64 bytes).

The hash uses only the public inputs provided to the module, not private inputs.

`module_hash` is the program hash of the compiled Cairo module.

## Implementation

See `calculate_task_hash` in `src/utils/utils.cairo`.
