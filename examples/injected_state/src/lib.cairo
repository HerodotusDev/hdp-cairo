#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Example: Basic usage of injected state memorizer primitives

        // 0. Read the tree root
        let (root, exists) = hdp.injected_state.read_injected_state_trie_root('my_trie');
        assert!(root == 0, "Tree root should be 0");
        assert!(exists, "Failed to read tree root");

        let (root, exists) = hdp.injected_state.read_injected_state_trie_root('my_troo');
        assert!(!exists, "Trie should not exist");
        assert!(root == 0, "Trie root should be 0");

        // 1. Store a key-value pair
        // let success = hdp.injected_state.upsert_key('my_key', 12345);
        // assert!(success, "Failed to upsert key-value pair");

        // 2. Read the value back
        // let (value, exists) = hdp.injected_state.read_key('my_key');
        // assert!(!exists, "Key should not exist");
        // assert!(value == 0, "Value should be 0");

        // 3. Check if key exists
        // let key_exists = hdp.injected_state.does_key_exist('my_key');
        // assert!(key_exists, "Key should exist");

        // 4. Check if non-existent key exists
        // let non_existent_key_exists = hdp.injected_state.does_key_exist('no_key');
        // assert!(!non_existent_key_exists, "Non-existent key should not exist");

        // 5. Update existing key
        // let success = hdp.injected_state.upsert_key('my_key', 54321);
        // assert!(success, "Failed to update key-value pair");

        // let (updated_value, exists) = hdp.injected_state.read_key('my_key');
        // assert!(exists, "Key should still exist");
        // assert!(updated_value == 54321, "Updated value should match");

        array![]
    }
}
