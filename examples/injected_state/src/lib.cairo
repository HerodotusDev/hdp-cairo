#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let (root, exists) = hdp.injected_state.read_injected_state_trie_root('my_trie');
        assert!(root == 0, "Tree root should be 0");
        assert!(exists, "Failed to read tree root");

        // let (root, exists) = hdp.injected_state.read_injected_state_trie_root('my_troo');
        // assert!(!exists, "Trie should not exist");
        // assert!(root == 0, "Trie root should be 0");

        // let (value, exists) = hdp.injected_state.read_key('my_trie', 'my_key');
        // assert!(!exists, "Key should not exist");
        // assert!(value == 0, "Value should be 0");

        // let key_exists = hdp.injected_state.does_key_exist('my_trie', 'my_key');
        // assert!(!key_exists, "Key should not exist");

        hdp.injected_state.write_key('my_trie', 'my_key', 42);
        let (value, exists) = hdp.injected_state.read_key('my_trie', 'my_key');
        assert!(exists, "Key should exist");
        assert!(value == 42, "Value should be 42");

        hdp.injected_state.write_key('my_trie', 'my_key2', 43);
        let (value, exists) = hdp.injected_state.read_key('my_trie', 'my_key2');
        assert!(exists, "Key should exist");
        assert!(value == 43, "Value should be 43");

        hdp.injected_state.write_key('my_trie', 'my_key3', 44);
        let (value, exists) = hdp.injected_state.read_key('my_trie', 'my_key3');
        assert!(exists, "Key should exist");
        assert!(value == 44, "Value should be 44");

        array![root]
    }
}
