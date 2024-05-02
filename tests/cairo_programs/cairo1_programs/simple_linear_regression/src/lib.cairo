use core::serde::Serde;
pub mod fraction;

#[cfg(test)]
mod tests;

use simple_linear_regression::fraction::fraction::FractionTrait;
use core::traits::Into;
use core::array::SpanTrait;
use core::array::ArrayTrait;
use fraction::fraction::{Fraction, FractionImpl, Sign};

#[derive(Drop, Serde)]
struct Input {
    x_i: Array<u256>,
    y_i: Array<u256>,
    predicted: Fraction,
}

fn main(input: Array<felt252>) -> () {
    let mut input_span = input.span();
    let input = Serde::<Input>::deserialize(ref input_span).unwrap();
    let regression = slr(input.x_i.span(), input.y_i.span());
    let mut output = array![];
    regression.predict(input.predicted).serialize(ref output);
    output;
}

#[derive(Drop, Copy, PartialEq)]
struct SLR {
    a_hat: Fraction,
    b_hat: Fraction
}

#[generate_trait]
impl SLRImpl of SLRTrait {
    fn predict(self: @SLR, x: Fraction) -> Fraction {
        *self.a_hat + *self.b_hat * x
    }
}

fn slr(x_i: Span<u256>, y_i: Span<u256>) -> SLR {
    let x_y = mul_arr(x_i, y_i).span();

    let sigma_x = sigma(x_i);
    let sigma_y = sigma(y_i);
    let sigma_xy = sigma(x_y);
    let sigma_x2 = sigma_squared(x_i);

    let num = FractionImpl::from_u256(Sign::Positive, sigma_xy)
        + FractionImpl::new(Sign::Negative, sigma_x * sigma_y, x_i.len().into());

    let denom = FractionImpl::from_u256(Sign::Positive, sigma_x2)
        + FractionImpl::new(Sign::Negative, sigma_x * sigma_x, x_i.len().into());

    let b_hat = num * denom.inv();
    let a_hat = FractionImpl::new(Sign::Positive, sigma_y, x_i.len().into())
        + FractionImpl::new(Sign::Negative, sigma_x, x_i.len().into()) * b_hat;

    SLR { a_hat, b_hat }
}

// ∑v
fn sigma(mut arr: Span<u256>) -> u256 {
    let mut ret = 0;
    loop {
        match arr.pop_front() {
            Option::Some(v) => { ret += *v; },
            Option::None => { break; }
        }
    };
    ret
}

// ∑(v^2)
fn sigma_squared(mut arr: Span<u256>) -> u256 {
    let mut ret = 0;
    loop {
        match arr.pop_front() {
            Option::Some(v) => { ret += *v * *v; },
            Option::None => { break; }
        }
    };
    ret
}

fn mul_arr(mut arr1: Span<u256>, mut arr2: Span<u256>) -> Array<u256> {
    let mut ret = array![];
    loop {
        match (arr1.pop_front(), arr2.pop_front()) {
            (Option::Some(v1), Option::Some(v2)) => { ret.append(*v1 * *v2); },
            _ => { break; }
        }
    };
    ret
}
