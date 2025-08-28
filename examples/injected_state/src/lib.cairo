#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let (root, exists) = hdp.injected_state.read_injected_state_trie_root('my_trie');
        assert!(root == 0x0, "Trie root should be 0x0");
        assert!(exists, "Failed to read tree root");

        let new_root = hdp.injected_state.write_key('my_trie', 'my_key', 42);
        assert!(
            new_root == 0xf153c6cd2bc40a4ec675068562f4ddefadc23030,
            "Trie root should be 0xf153c6cd2bc40a4ec675068562f4ddefadc23030",
        );

        let (value, exists) = hdp.injected_state.read_key('my_trie', 'my_key');
        assert!(exists, "Key should exist");
        assert!(value == 42, "Value should be 42");

        array![new_root]
    }
}
