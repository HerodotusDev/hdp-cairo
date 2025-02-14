#[starknet::contract]
mod contract {
    use hdp_cairo::{HDP};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        println!("Hello, world!");
    }
}
