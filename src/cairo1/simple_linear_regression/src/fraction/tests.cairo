use simple_linear_regression::fraction::fraction::{Fraction, FractionTrait, Sign};

#[test]
fn test_reduce() {
    let a = FractionTrait::new(Sign::Positive, 1728, 112032);
    assert!(*a.p() == 6);
    assert!(*a.q() == 389);
}

#[test]
fn test_add() {
    let a = FractionTrait::new(Sign::Positive, 4, 5);
    let b = FractionTrait::new(Sign::Positive, 7, 10);
    let c = FractionTrait::new(Sign::Positive, 3, 2);
    assert!(a + b == c);
}

#[test]
fn test_sub() {
    let a = FractionTrait::new(Sign::Positive, 4, 5);
    let b = FractionTrait::new(Sign::Positive, 3, 6);
    let c = FractionTrait::new(Sign::Positive, 3, 10);
    assert!(a - b == c);
}

#[test]
fn test_mul() {
    let a = FractionTrait::new(Sign::Positive, 4, 5);
    let b = FractionTrait::new(Sign::Positive, 7, 6);
    let c = FractionTrait::new(Sign::Positive, 14, 15);
    assert!(a * b == c);
}

#[test]
fn test_floor() {
    let a = FractionTrait::new(Sign::Positive, 6, 5);
    assert!(a.floor() == 1);
}

#[test]
fn test_ceil() {
    let a = FractionTrait::new(Sign::Positive, 6, 5);
    assert!(a.ceil() == 2);
}
