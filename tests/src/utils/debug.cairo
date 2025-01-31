#[starknet::contract]
mod test_debug_print {
    use hdp_cairo::debug::{print, print_array};
    use core::fmt::{Display, Formatter, Error};

    #[storage]
    struct Storage {}

    #[derive(Copy, Drop)]
    struct Point {
        x: u8,
        y: u8,
    }

    impl PointDisplay of Display<Point> {
        fn fmt(self: @Point, ref f: Formatter) -> Result<(), Error> {
            let str: ByteArray = format!("PointThatIAmMakingQuiteABitLongerToEnsureWeHaveMoreFelts ({}, {})", *self.x, *self.y);
            f.buffer.append(@str);
            Result::Ok(())
        }
    }

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        let p = Point { x: 1, y: 3 };
        
        print(p);
        print(1);
        print_array(array![1, 2, 3]);


    }
}
