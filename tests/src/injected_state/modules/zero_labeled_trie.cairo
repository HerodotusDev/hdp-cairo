#[starknet::contract]
mod zero_labeled_trie {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let root = hdp.injected_state.read_injected_state_trie_root(0x0).unwrap();
        assert!(root == 0x0, "Trie root should be 0x0");

        let value = hdp.injected_state.read_key(0x0, 'my_key');
        assert!(value.is_none(), "Value should not exist");

        let new_root = hdp.injected_state.write_key(0x0, 'my_key', 42);
        assert!(
            new_root == 0xf153c6cd2bc40a4ec675068562f4ddefadc23030,
            "Trie root should be 0xf153c6cd2bc40a4ec675068562f4ddefadc23030",
        );

        let value = hdp.injected_state.read_key(0x0, 'my_key').unwrap();
        assert!(value == 42, "Value should be 42");

        array![new_root]
    }
}
