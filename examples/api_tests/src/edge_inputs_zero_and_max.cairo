#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test edge inputs: zero and maximum values
        let label_zero = 0x0;
        let key_zero = 0x0;
        let val_zero = 0x0;

        // Test writing zero values
        let r0 = hdp.injected_state.write_key(label_zero, key_zero, val_zero);

        // Read back zero values
        let read_zero = hdp.injected_state.read_key(label_zero, key_zero).unwrap();
        assert!(read_zero == val_zero, "Zero values should be preserved");

        // Test maximum felt value (constrained by path length - 251 bits)
        // Use a 31-byte value with top bit clear
        let max = 0x03ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        let label = 'edge_inputs_max_test';

        // Write maximum values
        let r1 = hdp.injected_state.write_key(label, max, max);

        // Read back maximum values
        let read_max = hdp.injected_state.read_key(label, max).unwrap();
        assert!(read_max == max, "Maximum values should be preserved");

        // Verify both tries have non-zero roots
        let root_zero = hdp.injected_state.read_injected_state_trie_root(label_zero).unwrap();
        let root_max = hdp.injected_state.read_injected_state_trie_root(label).unwrap();

        assert!(root_zero != 0x0, "Zero trie should have non-zero root");
        assert!(root_max != 0x0, "Max trie should have non-zero root");

        array![r0, r1, root_zero, root_max]
    }
}
