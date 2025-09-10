#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test that writing the same value doesn't change the root
        let label = 'noop_write_test';
        let k = 0x2;
        let v = 0xC8; // 200 in decimal

        // First write
        let r1 = hdp.injected_state.write_key(label, k, v);

        // Write the same value again (no-op)
        let r2 = hdp.injected_state.write_key(label, k, v);

        // Same (key,value) should not change root
        assert!(r1 == r2, "No-op write should keep root unchanged");

        // Verify the value is still correct
        let read_value = hdp.injected_state.read_key(label, k).unwrap();
        assert!(read_value == v, "Value should remain unchanged after no-op write");

        // Verify trie root is unchanged
        let final_root = hdp.injected_state.read_injected_state_trie_root(label).unwrap();
        assert!(final_root == r1, "Trie root should remain unchanged");

        array![r1, r2, final_root]
    }
}
