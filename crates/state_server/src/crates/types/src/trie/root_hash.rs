use std::{fmt, ops::Deref};
use pathfinder_crypto::Felt;
use serde::{Deserialize, Serialize};

/// A thin wrapper around `Felt` to give it a distinct semantic meaning.
#[derive(
    Debug, Clone, Copy, PartialEq, Eq, Hash,
    Serialize, Deserialize,
)]
#[serde(transparent)]
pub struct RootHash(Felt);

impl RootHash {
    /// Create a new `Value`.
    #[inline]
    pub fn new(f: Felt) -> Self {
        RootHash(f)
    }

    /// The “zero” instance.
    #[inline]
    pub fn zero() -> Self {
        RootHash(Felt::ZERO)
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

impl Default for RootHash {
    #[inline]
    fn default() -> Self {
        RootHash::zero()
    }
}

impl From<Felt> for RootHash {
    #[inline]
    fn from(f: Felt) -> Self {
        RootHash(f)
    }
}

impl From<RootHash> for Felt {
    #[inline]
    fn from(v: RootHash) -> Felt {
        v.0
    }
}

/// So you can call `value.sqrt()` or pass `&Value` into APIs expecting `&Felt`.
impl Deref for RootHash {
    type Target = Felt;
    #[inline]
    fn deref(&self) -> &Felt {
        &self.0
    }
}

impl fmt::Display for RootHash {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}