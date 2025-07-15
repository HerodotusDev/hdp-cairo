// crates/types/src/trie/action.rs

use std::{
    fmt,
    ops::{Deref, DerefMut},
};

/// A thin wrapper around `String` for “actions.”
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Default)]
pub struct Action(String);

impl Action {
    /// Constructs a new `Action` from anything that can become a `String`.
    pub fn new<S: Into<String>>(s: S) -> Self {
        Action(s.into())
    }

    /// Get a `&str` view.
    pub fn as_str(&self) -> &str {
        &self.0
    }

    /// Consume and return the inner `String`.
    pub fn into_string(self) -> String {
        self.0
    }
}

// Allow *all* `String` methods on `&Action` / `&mut Action`
impl Deref for Action {
    type Target = String;
    fn deref(&self) -> &String {
        &self.0
    }
}
impl DerefMut for Action {
    fn deref_mut(&mut self) -> &mut String {
        &mut self.0
    }
}

// Display as the inner string
impl fmt::Display for Action {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

// Conversions to and from `String` / `&str`
impl From<String> for Action {
    fn from(s: String) -> Self {
        Action(s)
    }
}
impl From<&str> for Action {
    fn from(s: &str) -> Self {
        Action(s.to_string())
    }
}
impl From<Action> for String {
    fn from(a: Action) -> String {
        a.0
    }
}