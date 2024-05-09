use core::debug::PrintTrait;
use core::fmt::Debug;
use simple_linear_regression::SLRTrait;
use simple_linear_regression::{slr, main};
use cubit::f128::math::{ops, hyp, trig};
use cubit::f128::{Fixed as Fixed128, FixedTrait as FixedTrait128, ONE};
use cubit::f128::test::helpers::assert_precise;

#[test]
fn test_slr_simple() {
    let slr = slr(
        array![
            FixedTrait128::new_unscaled(1, false),
            FixedTrait128::new_unscaled(2, false),
            FixedTrait128::new_unscaled(3, false),
            FixedTrait128::new_unscaled(4, false),
            FixedTrait128::new_unscaled(5, false),
            FixedTrait128::new_unscaled(6, false)
        ]
            .span(),
        array![
            FixedTrait128::new_unscaled(3, false),
            FixedTrait128::new_unscaled(5, false),
            FixedTrait128::new_unscaled(7, false),
            FixedTrait128::new_unscaled(9, false),
            FixedTrait128::new_unscaled(11, false),
            FixedTrait128::new_unscaled(13, false)
        ]
            .span()
    );
    let prediction = slr.predict(FixedTrait128::new_unscaled(10, false));
    assert_precise(prediction, 21 * ONE, 'Invalid value', Option::None);
}

#[test]
fn test_main() {
    let prediction = main(
        array![2, 1 * ONE, 0, 2 * ONE, 0, 2, 3 * ONE, 0, 5 * ONE, 0, 10 * ONE, 0]
    );
    assert_precise(prediction, 21 * ONE, 'Invalid value', Option::None);
}
