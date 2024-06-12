pub mod header_memorizer;

#[derive(Serde, Drop)]
pub struct HDP {
    pub header_memorizer: Memorizer
}

#[derive(Serde, Drop)]
pub struct RelocatableValue {
    pub segment_index: felt252,
    pub offset: felt252,
}

#[derive(Serde, Drop)]
struct Memorizer {
    pub dict: RelocatableValue,
    pub list: RelocatableValue,
}
