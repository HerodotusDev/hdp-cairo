#[starknet::contract]
mod example {
    use hdp_cairo::{HDP, evm::storage::{StorageImpl}, any_type::any_type};
    use hdp_cairo::debug::{print_array};

    #[storage]
    struct Storage {}

    #[derive(Serde, Drop)]
    struct AnyTypeInput {
        pub item_a: felt252,
        pub item_b: Array<felt252>,
    }

    #[derive(Serde, Drop)]
    struct AnyTypeOutput {
        pub item_a: felt252,
        pub item_b: Array<felt252>,
        pub item_c: felt252,
    }

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        let s = AnyTypeInput { item_a: 1, item_b: array![2, 3, 4, 5, 6] };

        let mut s_obj_serialized = array![];
        s.serialize(ref s_obj_serialized);
        print_array(s_obj_serialized);

        let d: AnyTypeOutput = any_type(s);

        let mut d_obj_serialized = array![];
        d.serialize(ref d_obj_serialized);
        print_array(d_obj_serialized);
    }
}
