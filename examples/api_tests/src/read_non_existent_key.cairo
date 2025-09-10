#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test parameters matching the Rust test
        let label = 'non_existent_key_test';
        let k1 = 0x1;
        let k2 = 0x2;
        let v1 = 0x1;

        // Write one key to the trie
        let root = hdp.injected_state.write_key(label, k1, v1);
        assert!(root != 0x0, "Root must change from zero after first write");

        // Test reading non-existent key
        let non_existent_value = hdp.injected_state.read_key(label, k2);
        assert!(non_existent_value.is_none(), "Non-existent key should return None");

        // Verify the existing key still works
        let existing_value = hdp.injected_state.read_key(label, k1).unwrap();
        assert!(existing_value == v1, "Existing key should return correct value");

        array![root, existing_value]
    }
}
