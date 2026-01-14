pub mod arbitrary_type;
pub mod eth_call;
pub mod evm;
pub mod injected_state;
pub mod starknet;
pub mod unconstrained;

// Cairo Zero EVM execution (via syscall)
pub use eth_call::execute_call_zero::execute_eth_call_zero;
pub use eth_call::execute_call_zero::EvmCallResult;

// Shared utilities
pub use eth_call::hdp_backend::TimeAndSpace;

#[derive(Serde, Drop)]
pub struct HDP {
    pub evm: EvmMemorizer,
    pub starknet: StarknetMemorizer,
    pub injected_state: InjectedStateMemorizer,
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
