use super::SLRTrait;
use super::{slr};
use super::fraction::fraction::{Fraction, FractionImpl, FractionTrait, Sign};

#[test]
fn test_slr_simple() {
    let slr = slr(
        array![
            FractionImpl::from_u256(Sign::Positive, 1),
            FractionImpl::from_u256(Sign::Positive, 2),
            FractionImpl::from_u256(Sign::Positive, 3),
            FractionImpl::from_u256(Sign::Positive, 4),
            FractionImpl::from_u256(Sign::Positive, 5),
            FractionImpl::from_u256(Sign::Positive, 6),
        ]
            .span(),
        array![
            FractionImpl::from_u256(Sign::Positive, 3),
            FractionImpl::from_u256(Sign::Positive, 5),
            FractionImpl::from_u256(Sign::Positive, 7),
            FractionImpl::from_u256(Sign::Positive, 9),
            FractionImpl::from_u256(Sign::Positive, 11),
            FractionImpl::from_u256(Sign::Positive, 13),
        ]
            .span()
    );
    let prediction = slr.predict(FractionImpl::from_u256(Sign::Positive, 10));
    assert(prediction == FractionImpl::from_u256(Sign::Positive, 21), 'Invalid value');
}
