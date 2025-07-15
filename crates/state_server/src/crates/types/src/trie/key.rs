use std::{fmt, ops::Deref};
use pathfinder_crypto::Felt;
use serde::{Deserialize, Serialize};

/// A thin wrapper around `Felt` to represent a cryptographic key.
#[derive(
    Debug, Clone, Copy, PartialEq, Eq, Hash,
    Serialize, Deserialize,
)]
#[serde(transparent)]
pub struct Key(Felt);

impl Key {
    /// Wrap a raw `Felt` as a `Key`.
    #[inline]
    pub fn new(inner: Felt) -> Self {
        Key(inner)
    }

    /// Borrow the inner `Felt`.
    #[inline]
    pub fn inner(&self) -> &Felt {
        &self.0
    }

    /// Consume the wrapper and return the raw `Felt`.
    #[inline]
    pub fn into_inner(self) -> Felt {
        self.0
    }
}

impl Default for Key {
    #[inline]
    fn default() -> Self {
        // You could choose to panic here instead if having a "zero" key makes no sense.
        Key(Felt::ZERO)
    }
}

impl From<Felt> for Key {
    #[inline]
    fn from(f: Felt) -> Self {
        Key(f)
    }
}

impl From<Key> for Felt {
    #[inline]
    fn from(k: Key) -> Felt {
        k.0
    }
}

/// Let you call any `Felt` methods on a `Key`, and pass `&Key` where `&Felt` is expected.
impl Deref for Key {
    type Target = Felt;
    #[inline]
    fn deref(&self) -> &Felt {
        &self.0
    }
}

impl fmt::Display for Key {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}