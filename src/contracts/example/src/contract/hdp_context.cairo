pub mod header_memorizer;

#[derive(Serde, Drop)]
pub struct HDP {
    pub header_memorizer: Memorizer
}

#[derive(Serde, Drop)]
struct Memorizer {
    pub segment: felt252,
    pub offset: felt252,
}
