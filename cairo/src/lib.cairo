pub mod memorizer;

#[derive(Serde, Drop)]
pub struct HDP {
    pub header_memorizer: Memorizer,
    pub account_memorizer: Memorizer,
    pub storage_memorizer: Memorizer,
}

#[derive(Serde, Drop)]
pub struct RelocatableValue {
    pub segment_index: felt252,
    pub offset: felt252,
}

#[derive(Serde, Drop)]
struct Memorizer {
    pub dict: RelocatableValue,
}
