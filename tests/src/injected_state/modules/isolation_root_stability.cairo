#[starknet::contract]
mod isolation_root_stability {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test that different tries are isolated - writing to one doesn't affect another
        let trie_a = 'isolation_trie_a';
        let trie_b = 'isolation_trie_b';

        // Initial roots are zero (implicit)
        let root_a_0 = 0x0;
        let root_b_0 = 0x0;

        // Write to trie A
        let k1 = 0x1;
        let v1 = 0x64; // 100 in decimal
        let root_a_1 = hdp.injected_state.write_key(trie_a, k1, v1);

        assert!(root_a_0 != root_a_1, "Trie A root must change after write");

        // Trie B root should remain zero; reading from B yields zero
        assert!(root_b_0 == 0x0, "Trie B root should remain zero");

        // Read from trie B (should return None since key doesn't exist)
        let resp_b = hdp.injected_state.read_key(trie_b, k1);
        assert!(resp_b.is_none(), "Trie B should return None for non-existent key");

        // Verify trie A has the correct value
        let resp_a = hdp.injected_state.read_key(trie_a, k1).unwrap();
        assert!(resp_a == v1, "Trie A should return the written value");

        // Verify trie B root is still zero
        let trie_b_root = hdp.injected_state.read_injected_state_trie_root(trie_b).unwrap();
        assert!(trie_b_root == 0x0, "Trie B root should still be zero");

        array![root_a_1, trie_b_root]
    }
}
