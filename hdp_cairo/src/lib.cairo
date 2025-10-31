pub mod arbitrary_type;
pub mod bytecode;
pub mod debug;
pub mod evm;
pub mod injected_state;
pub mod starknet;

#[derive(Serde, Drop)]
pub struct HDP {
    pub evm: EvmMemorizer,
    pub starknet: StarknetMemorizer,
    pub injected_state: InjectedStateMemorizer,
    // TODO: @Okm165 [done?]
    pub unconstrained: UnconstrainedMemorizer,
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

#[derive(Serde, Drop)]
struct InjectedStateMemorizer {
    pub dict: RelocatableValue,
}

#[derive(Serde, Drop)]
struct UnconstrainedMemorizer {
    pub dict: RelocatableValue,
}
