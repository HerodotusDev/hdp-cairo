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

        let (root, exists) = hdp.injected_state.read_injected_state_trie_root('my_troo');
        assert!(!exists, "Trie should not exist");
        assert!(root == 0, "Trie root should be 0");

        let (value, exists) = hdp.injected_state.read_key('my_trie', 'my_key');
        assert!(!exists, "Key should not exist");
        assert!(value == 0, "Value should be 0");

        let key_exists = hdp.injected_state.does_key_exist('my_trie', 'my_key');
        assert!(!key_exists, "Key should not exist");

        array![root]
    }
}
