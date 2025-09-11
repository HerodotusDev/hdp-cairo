#[starknet::contract]
mod edge_inputs_max {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
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
        let root_max = hdp.injected_state.read_injected_state_trie_root(label).unwrap();

        assert!(root_max != 0x0, "Max trie should have non-zero root");

        array![r1, root_max]
    }
}
