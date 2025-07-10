#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Example: Basic usage of injected state memorizer primitives

        // 0. Set the persistent tree root
        let success = hdp.injected_state.set_injected_state_root(0x424242);
        assert!(success, "Failed to set tree root");

        // 1. Store a key-value pair
        let success = hdp.injected_state.upsert_key('my_key', 12345);
        assert!(success, "Failed to upsert key-value pair");

        // 2. Read the value back
        let (value, exists) = hdp.injected_state.read_key('my_key');
        assert!(exists, "Key should exist");
        assert!(value == 12345, "Value should match");

        // 3. Check if key exists
        let key_exists = hdp.injected_state.does_key_exist('my_key');
        assert!(key_exists, "Key should exist");

        // 4. Check if non-existent key exists
        let non_existent_key_exists = hdp.injected_state.does_key_exist('no_key');
        assert!(!non_existent_key_exists, "Non-existent key should not exist");

        // 5. Update existing key
        let success = hdp.injected_state.upsert_key('my_key', 54321);
        assert!(success, "Failed to update key-value pair");

        let (updated_value, exists) = hdp.injected_state.read_key('my_key');
        assert!(exists, "Key should still exist");
        assert!(updated_value == 54321, "Updated value should match");

        array![value, updated_value]
    }
}
