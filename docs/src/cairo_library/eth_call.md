# eth_call

HDP includes a provable EVM interpreter that can execute `eth_call`-style requests inside Cairo.

## Entry point

`hdp_cairo` re-exports the helper:

- `execute_eth_call(hdp, time_and_space, sender, target, calldata)`

Source: `hdp_cairo/src/eth_call/execute_call.cairo`

## What it does

- Builds an EIP-1559 transaction wrapper for the call
- Executes an EVM interpreter in Cairo
- Reads required state through HDP memorizers
- Returns a `TransactionResult` with success flag and return data

## Supported instructions

The interpreter is implemented in `hdp_cairo/src/eth_call/evm/instructions/`. If you need to verify opcode coverage, start there and in `hdp_cairo/src/eth_call/evm/instructions.cairo`.

## Limitations

- The interpreter is designed for `eth_call`-style execution (no state mutation).
- Opcode coverage is intentionally scoped; check the instruction modules for details.

## Example

```cairo
use hdp_cairo::{HDP, execute_eth_call};
use hdp_cairo::eth_call::hdp_backend::TimeAndSpace;
use starknet::EthAddress;

let time_and_space = TimeAndSpace { chain_id: 0x1, block_number: 18_500_000 };
let result = execute_eth_call(
    @hdp,
    @time_and_space,
    EthAddress::from(0x01),
    EthAddress::from(0x02),
    array![0x12, 0x34].span(),
);
```
