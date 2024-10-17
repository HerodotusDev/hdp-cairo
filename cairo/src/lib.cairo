pub mod evm;

#[derive(Serde, Drop)]
pub struct HDP {
    pub evm: EvmMemorizer,
    // pub starknet: StarknetMemorizer,
}

#[derive(Serde, Drop)]
pub struct RelocatableValue {
    pub segment_index: felt252,
    pub offset: felt252,
}

#[derive(Serde, Drop)]
struct EvmMemorizer {
    pub dict: RelocatableValue,
}

#[derive(Serde, Drop)]
struct StarknetMemorizer {
    pub dict: RelocatableValue,
}