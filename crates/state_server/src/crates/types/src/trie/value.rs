use std::{fmt, ops::Deref};
use pathfinder_crypto::Felt;
use serde::{Deserialize, Serialize};

/// A thin wrapper around `Felt` to give it a distinct semantic meaning.
#[derive(
    Debug, Clone, Copy, PartialEq, Eq, Hash,
    Serialize, Deserialize,
)]
#[serde(transparent)]
pub struct Value(Felt);

impl Value {
    /// Create a new `Value`.
    #[inline]
    pub fn new(f: Felt) -> Self {
        Value(f)
    }

    /// The “zero” instance.
    #[inline]
    pub fn zero() -> Self {
        Value(Felt::ZERO)
    }

    /// Get a copy of the inner `Felt`.
    #[inline]
    pub fn into_inner(self) -> Felt {
        self.0
    }

    /// Borrow the inner `Felt`.
    #[inline]
    pub fn inner(&self) -> &Felt {
        &self.0
    }
}

impl Default for Value {
    #[inline]
    fn default() -> Self {
        Value::zero()
    }
}

impl From<Felt> for Value {
    #[inline]
    fn from(f: Felt) -> Self {
        Value(f)
    }
}

impl From<Value> for Felt {
    #[inline]
    fn from(v: Value) -> Felt {
        v.0
    }
}

/// So you can call `value.sqrt()` or pass `&Value` into APIs expecting `&Felt`.
impl Deref for Value {
    type Target = Felt;
    #[inline]
    fn deref(&self) -> &Felt {
        &self.0
    }
}

impl fmt::Display for Value {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}