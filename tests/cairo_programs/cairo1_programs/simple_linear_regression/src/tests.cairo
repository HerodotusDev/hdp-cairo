use simple_linear_regression::SLRTrait;
use simple_linear_regression::{slr, main};
use simple_linear_regression::fraction::fraction::{FractionImpl, Sign};

#[test]
fn test_slr_simple() {
    let slr = slr(array![1, 2, 3, 4, 5, 6].span(), array![3, 5, 7, 9, 11, 13].span());
    let prediction = slr.predict(FractionImpl::from_u256(Sign::Positive, 10));
    assert!(prediction == FractionImpl::from_u256(Sign::Positive, 21));
}

#[test]
fn test_main() {
    let prediction = main(array![2, 1, 0, 2, 0, 2, 3, 0, 5, 0, 0, 10, 0, 1, 0]);
    assert!(prediction == FractionImpl::from_u256(Sign::Positive, 21));
}
