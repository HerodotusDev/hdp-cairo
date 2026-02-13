# Cairo Library Overview

The `hdp_cairo` package exposes the Cairo1 API for accessing verified data in HDP. Your Cairo module receives an `HDP` instance with memorizers for each data domain.

## HDP struct

```cairo
pub struct HDP {
    pub evm: EvmMemorizer,
    pub starknet: StarknetMemorizer,
    pub injected_state: InjectedStateMemorizer,
    pub unconstrained: UnconstrainedMemorizer,
}
```

Source: `hdp_cairo/src/lib.cairo`

## Basic usage

```cairo
#[starknet::contract]
mod example {
    use hdp_cairo::HDP;
    use hdp_cairo::evm::header::{HeaderKey, HeaderImpl};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32) -> u256 {
        hdp.evm.header_get_timestamp(
            HeaderKey { chain_id: 0x1, block_number: block_number.into() }
        )
    }
}
```

Your module should expose a `main` entrypoint (or a chosen external entrypoint) that receives an `HDP` instance and any module-specific inputs.

The rest of this section documents the module-specific APIs.
