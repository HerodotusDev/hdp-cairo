#[starknet::contract]
mod hashers_pedersen {
    use core::pedersen::{pedersen};
    use hdp_cairo::{HDP};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        let hash1 = pedersen(1, 2);
        let hash2 = pedersen(3, 4);

        assert!(hash1 == 0x5bb9440e27889a364bcb678b1f679ecd1347acdedcbf36e83494f857cc58026);
        assert!(hash2 == 0x262697b88544f733e5c6907c3e1763131e9f14c51ee7951258abbfb29415fbf);
    }
}
