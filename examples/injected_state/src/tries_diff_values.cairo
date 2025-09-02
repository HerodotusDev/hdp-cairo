#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let root_1 = hdp.injected_state.write_key('trie_1', 'key_1', 42);
        let root_2 = hdp.injected_state.write_key('trie_2', 'key_2', 43);

        let (value, exists) = hdp.injected_state.read_key('trie_1', 'key_2');
        assert!(!exists, "Key should not exist");
        assert!(value == 0x0, "Value should be 0");

        let (value, exists) = hdp.injected_state.read_key('trie_2', 'key_1');
        assert!(!exists, "Key should not exist");
        assert!(value == 0x0, "Value should be 0");

        let new_root_1 = hdp.injected_state.write_key('trie_1', 'key_3', 44);
        assert!(new_root_1 != root_1, "Root should have changed");

        let (new_root_2, exists) = hdp.injected_state.read_injected_state_trie_root('trie_2');
        assert!(exists, "Root should exist");
        assert!(new_root_2 == root_2, "We shall not have collisions");

        let (value, exists) = hdp.injected_state.read_key('trie_2', 'key_3');
        assert!(!exists, "Key should not exist");
        assert!(value == 0x0, "Value should be 0");

        let (value, exists) = hdp.injected_state.read_key('trie_1', 'key_1');
        assert!(exists, "Key should still exist");
        assert!(value == 42, "Value should be 42");

        array![new_root_1, new_root_2]
    }
}
