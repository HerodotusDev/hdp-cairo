## Debugging Guide

Effective debugging is key to rapidly identifying and resolving issues while writing your custom Cairo module.

### Printing Debug Messages

To help with debugging, you can use the `println!` macro to print debug messages to the console.

To disable the validation pass while developing and using that macro, you can add the following to your `Scarb.toml`:

```toml
[[target.starknet-contract]]
allowed-libfuncs-deny = true
```

```rust
#[starknet::contract]
mod contract {
    use hdp_cairo::{HDP};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(
        ref self: ContractState,
        hdp: HDP
    ) {
        println!("Hello, world!");
    }
}
```

Apply these practices to streamline your debugging workflow and quickly trace bugs.

Happy debugging!
