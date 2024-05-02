use core::traits::{Add, Mul, Sub, Div};

#[derive(Drop, Copy, PartialEq, Serde)]
pub enum Sign {
    Positive,
    Negative
}

#[derive(Drop, Copy, PartialEq, Serde)]
pub struct Fraction {
    sign: Sign,
    p: u256,
    q: u256,
}

#[generate_trait]
pub impl FractionImpl of FractionTrait {
    fn new(sign: Sign, p: u256, q: u256) -> Fraction {
        Fraction { sign, p, q }.reduce()
    }

    fn from_u256(sign: Sign, p: u256) -> Fraction {
        Fraction { sign, p, q: 1 }
    }

    fn reduce(self: Fraction) -> Fraction {
        let gcd = gcd_two_numbers(self.p, self.q);
        Fraction { sign: self.sign, p: self.p / gcd, q: self.q / gcd }
    }

    fn p(self: @Fraction) -> @u256 {
        self.p
    }

    fn q(self: @Fraction) -> @u256 {
        self.q
    }

    fn sign(self: @Fraction) -> @Sign {
        self.sign
    }

    fn inv(self: Fraction) -> Fraction {
        Fraction { sign: self.sign, p: self.q, q: self.p }
    }

    fn neg(self: Fraction) -> Fraction {
        match self.sign {
            Sign::Positive => Fraction { sign: Sign::Negative, p: self.p, q: self.q },
            Sign::Negative => Fraction { sign: Sign::Positive, p: self.p, q: self.q },
        }
    }
}

impl AddFraction of Add<Fraction> {
    fn add(lhs: Fraction, rhs: Fraction) -> Fraction {
        match (lhs.sign, rhs.sign) {
            (
                Sign::Positive, Sign::Positive
            ) => {
                Fraction {
                    sign: Sign::Positive, p: lhs.p * rhs.q + lhs.q * rhs.p, q: lhs.q * rhs.q
                }
                    .reduce()
            },
            (
                Sign::Negative, Sign::Negative
            ) => {
                Fraction {
                    sign: Sign::Negative, p: lhs.p * rhs.q + lhs.q * rhs.p, q: lhs.q * rhs.q
                }
                    .reduce()
            },
            _ => {
                let l = lhs.p * rhs.q;
                let r = lhs.q * rhs.p;

                if l < r {
                    Fraction { sign: Sign::Negative, p: r - l, q: lhs.q * rhs.q }.reduce()
                } else {
                    Fraction { sign: Sign::Positive, p: l - r, q: lhs.q * rhs.q }.reduce()
                }
            }
        }
    }
}

impl MulFraction of Mul<Fraction> {
    fn mul(lhs: Fraction, rhs: Fraction) -> Fraction {
        match (lhs.sign, rhs.sign) {
            (
                Sign::Positive, Sign::Positive
            ) => { Fraction { sign: Sign::Positive, p: lhs.p * rhs.p, q: lhs.q * rhs.q }.reduce() },
            (
                Sign::Negative, Sign::Negative
            ) => { Fraction { sign: Sign::Positive, p: lhs.p * rhs.p, q: lhs.q * rhs.q }.reduce() },
            _ => { Fraction { sign: Sign::Negative, p: lhs.p * rhs.p, q: lhs.q * rhs.q }.reduce() }
        }
    }
}

// Internal function to calculate the gcd between two numbers
// # Arguments
// * `a` - The first number for which to calculate the gcd
// * `b` - The first number for which to calculate the gcd
// # Returns
// * `u256` - The gcd of a and b
pub fn gcd_two_numbers(mut a: u256, mut b: u256) -> u256 {
    while b != 0 {
        let r = a % b;
        a = b;
        b = r;
    };
    a
}
