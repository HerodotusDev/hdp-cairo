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
    let prediction = main(array![2, 1, 0, 3, 0, 2, 0, 5, 0, 10, 0]);
    assert_precise(prediction, 21, 'Invalid value', Option::None);
}

#[test]
fn test_main_big() {
    let prediction = main(
        array![
            20,
            4952200,
            0,
            41695449092418133180,
            0,
            4952210,
            0,
            41695297248112512876,
            0,
            4952220,
            0,
            41695126079992231516,
            0,
            4952230,
            0,
            41694965332469803456,
            0,
            4952240,
            0,
            41694750350349880528,
            0,
            4952250,
            0,
            41694573469806694504,
            0,
            4952260,
            0,
            41694371644926860360,
            0,
            4952270,
            0,
            41694203744673754488,
            0,
            4952280,
            0,
            41693993303196883368,
            0,
            4952290,
            0,
            41693827135070089408,
            0,
            4952300,
            0,
            41693638104975915688,
            0,
            4952310,
            0,
            41693469218893133480,
            0,
            4952320,
            0,
            41693290108934842520,
            0,
            4952330,
            0,
            41693124970550935440,
            0,
            4952340,
            0,
            41692934181610012284,
            0,
            4952350,
            0,
            41692771888310808220,
            0,
            4952360,
            0,
            41692592497030758252,
            0,
            4952370,
            0,
            41692407403054878072,
            0,
            4952380,
            0,
            41692213781816509572,
            0,
            4952390,
            0,
            41692050035525129316,
            0,
            4952400,
            0,
            41691885935980067916,
            0,
            4952410,
            0
        ]
    );
    assert_precise(prediction, 41691856156838895636, 'Invalid value', Option::None);
}
