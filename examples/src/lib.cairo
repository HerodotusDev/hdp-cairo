#[starknet::contract]
mod example {
    use hdp_cairo::{HDP, evm::storage::{StorageImpl}, any_type::any_type};
    use hdp_cairo::debug::{print};
    use core::fmt::{Display, Formatter, Error};

    #[storage]
    struct Storage {}

    #[derive(Serde, Drop)]
    struct AnyTypeInput {
        pub item_a: felt252,
        pub item_b: felt252,
        pub item_c: felt252,
        pub item_d: felt252,
    }

    impl AnyTypeInputDisplay of Display<AnyTypeInput> {
        fn fmt(self: @AnyTypeInput, ref f: Formatter) -> Result<(), Error> {
            let str: ByteArray = format!(
                "item_a: {}, item_b: {}, item_c: {}, item_d: {}",
                *self.item_a,
                *self.item_b,
                *self.item_c,
                *self.item_d,
            );
            f.buffer.append(@str);
            Result::Ok(())
        }
    }

    #[derive(Serde, Drop)]
    struct AnyTypeOutput {
        pub item_a: felt252,
        pub item_b: felt252,
        pub item_c: felt252,
        pub item_d: felt252,
        pub item_e: felt252,
        pub item_f: felt252,
    }

    impl AnyTypeOutputDisplay of Display<AnyTypeOutput> {
        fn fmt(self: @AnyTypeOutput, ref f: Formatter) -> Result<(), Error> {
            let str: ByteArray = format!(
                "item_a: {}, item_b: {}, item_c: {}, item_d: {}, item_e: {}, item_f: {}",
                *self.item_a,
                *self.item_b,
                *self.item_c,
                *self.item_d,
                *self.item_e,
                *self.item_f,
            );
            f.buffer.append(@str);
            Result::Ok(())
        }
    }

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        let s = AnyTypeInput { item_a: 1, item_b: 2, item_c: 9, item_d: 4 };
        let d: AnyTypeOutput = any_type(s);
        print(d);
    }
}
