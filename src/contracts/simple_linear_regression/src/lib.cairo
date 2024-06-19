#[starknet::contract]
mod slr {
    pub mod hdp_context;
    use hdp_context::HDP;

    pub mod fraction;
    use fraction::fraction::{Fraction, FractionImpl, FractionTrait, Sign};

    #[cfg(test)]
    pub mod tests;

    #[derive(Drop, Serde)]
    struct Input {
        xy_i: Array<(u256, u256)>,
        predicted: u256,
    }

    #[derive(Drop, Copy, PartialEq)]
    struct SLR {
        a_hat: Fraction,
        b_hat: Fraction,
    }

    #[generate_trait]
    impl SLRImpl of SLRTrait {
        fn predict(self: @SLR, x: Fraction) -> Fraction {
            *self.a_hat + *self.b_hat * x
        }
    }

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, mut input: Input) -> u256 {
        let mut x_i = array![];
        let mut y_i = array![];

        loop {
            match input.xy_i.pop_front() {
                Option::Some((
                    x, y
                )) => {
                    x_i.append(FractionImpl::from_u256(Sign::Positive, x));
                    y_i.append(FractionImpl::from_u256(Sign::Positive, y));
                },
                Option::None => { break; }
            }
        };

        let regression = slr(x_i.span(), y_i.span());
        regression.predict(FractionImpl::from_u256(Sign::Positive, input.predicted)).floor()
    }

    fn slr(x_i: Span<Fraction>, y_i: Span<Fraction>) -> SLR {
        let x_y = mul_arr(x_i, y_i).span();

        let sigma_x = sigma(x_i);
        let sigma_y = sigma(y_i);
        let sigma_xy = sigma(x_y);
        let sigma_x2 = sigma_squared(x_i);
        let n = FractionImpl::from_u256(Sign::Positive, x_i.len().into());

        let num = sigma_xy - (sigma_x * sigma_y) / n;
        let denom = sigma_x2 - (sigma_x * sigma_x) / n;
        let b_hat = num / denom;
        let a_hat = (sigma_y / n) - (sigma_x / n) * b_hat;

        SLR { a_hat, b_hat }
    }

    // ∑v
    fn sigma(mut arr: Span<Fraction>) -> Fraction {
        let mut ret = FractionImpl::from_u256(Sign::Positive, 0);
        loop {
            match arr.pop_front() {
                Option::Some(v) => { ret = ret + *v; },
                Option::None => { break; }
            }
        };
        ret
    }

    // ∑(v^2)
    fn sigma_squared(mut arr: Span<Fraction>) -> Fraction {
        let mut ret = FractionImpl::from_u256(Sign::Positive, 0);
        loop {
            match arr.pop_front() {
                Option::Some(v) => { ret = ret + *v * *v; },
                Option::None => { break; }
            }
        };
        ret
    }

    fn mul_arr(mut arr1: Span<Fraction>, mut arr2: Span<Fraction>) -> Array<Fraction> {
        let mut ret = array![];
        loop {
            match (arr1.pop_front(), arr2.pop_front()) {
                (Option::Some(v1), Option::Some(v2)) => { ret.append(*v1 * *v2); },
                _ => { break; }
            }
        };
        ret
    }
}
