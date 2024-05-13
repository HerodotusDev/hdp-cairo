use core::serde::Serde;
use cubit::f128::math::{ops, hyp, trig};
use cubit::f128::{Fixed as Fixed128, FixedTrait as FixedTrait128};

#[cfg(test)]
mod tests;

#[derive(Drop, Serde)]
struct Input {
    xy_i: Array<(u256, u256)>,
    predicted: u256,
}

fn main(input: Array<felt252>) -> u256 {
    let mut input_span = input.span();
    let mut input = Serde::<Input>::deserialize(ref input_span).unwrap();

    let mut x_i = array![];
    let mut y_i = array![];

    loop {
        match input.xy_i.pop_front() {
            Option::Some((
                x, y
            )) => {
                x_i.append(FixedTrait128::new_unscaled(x.try_into().unwrap(), false));
                y_i.append(FixedTrait128::new(y.try_into().unwrap(), false));
            },
            Option::None => { break; }
        }
    };

    let regression = slr(x_i.span(), y_i.span());
    let prediction = regression
        .predict(FixedTrait128::new_unscaled(input.predicted.try_into().unwrap(), false));
    u256 { low: prediction.mag, high: 0 }
}

#[derive(Drop, Copy, PartialEq)]
struct SLR {
    a_hat: Fixed128,
    b_hat: Fixed128
}

#[generate_trait]
impl SLRImpl of SLRTrait {
    fn predict(self: @SLR, x: Fixed128) -> Fixed128 {
        *self.a_hat + *self.b_hat * x
    }
}

fn slr(x_i: Span<Fixed128>, y_i: Span<Fixed128>) -> SLR {
    let x_y = mul_arr(x_i, y_i).span();

    let sigma_x = sigma(x_i);
    let sigma_y = sigma(y_i);
    let sigma_xy = sigma(x_y);
    let sigma_x2 = sigma_squared(x_i);
    let n = FixedTrait128::new_unscaled(x_i.len().into(), false);

    let num = sigma_xy - (sigma_x * sigma_y) / n;
    let denom = sigma_x2 - (sigma_x * sigma_x) / n;
    let b_hat = num / denom;
    let a_hat = (sigma_y / n) - (sigma_x / n) * b_hat;

    SLR { a_hat, b_hat }
}

// ∑v
fn sigma(mut arr: Span<Fixed128>) -> Fixed128 {
    let mut ret = FixedTrait128::new_unscaled(0, false);
    loop {
        match arr.pop_front() {
            Option::Some(v) => { ret += *v; },
            Option::None => { break; }
        }
    };
    ret
}

// ∑(v^2)
fn sigma_squared(mut arr: Span<Fixed128>) -> Fixed128 {
    let mut ret = FixedTrait128::new_unscaled(0, false);
    loop {
        match arr.pop_front() {
            Option::Some(v) => { ret += *v * *v; },
            Option::None => { break; }
        }
    };
    ret
}

fn mul_arr(mut arr1: Span<Fixed128>, mut arr2: Span<Fixed128>) -> Array<Fixed128> {
    let mut ret = array![];
    loop {
        match (arr1.pop_front(), arr2.pop_front()) {
            (Option::Some(v1), Option::Some(v2)) => { ret.append(*v1 * *v2); },
            _ => { break; }
        }
    };
    ret
}
