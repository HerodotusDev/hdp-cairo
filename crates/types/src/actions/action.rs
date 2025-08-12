use pathfinder_crypto::Felt;
use serde::{Deserialize, Serialize};
use strum_macros::FromRepr;

#[derive(FromRepr, Debug)]
pub enum CallHandlerId {
    ReadKey = 0,
    UpsertKey = 1,
    DoesKeyExist = 2,
    SetTreeRoot = 3,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum ActionType {
    Read = 0,
    Write = 1,
}

impl ActionType {
    fn as_u8(self) -> u8 {
        self as u8
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Action {
    pub root_hash: Felt,
    pub action_type: ActionType,
    pub key: Felt,
    pub value: Option<Felt>,
}

impl Action {
    pub fn new(root_hash: Felt, action_type: ActionType, key: Felt, value: Option<Felt>) -> Self {
        Self {
            root_hash,
            action_type,
            key,
            value,
        }
    }

    /// Serialize action to string format: "root_hash;action_type;key[;value]"
    pub fn serialize(&self) -> String {
        match self.action_type {
            ActionType::Read => format!("{};{};{}", self.root_hash, self.action_type.as_u8(), self.key),
            ActionType::Write => match &self.value {
                Some(val) => format!("{};{};{};{}", self.root_hash, self.action_type.as_u8(), self.key, val),
                None => format!("{};{};{}", self.root_hash, self.action_type.as_u8(), self.key),
            },
        }
    }

    /// Deserialize action from string format: "root_hash;action_type;key[;value]"
    pub fn deserialize(action_str: &str) -> Result<Self, anyhow::Error> {
        let parts: Vec<&str> = action_str.split(';').collect();

        if parts.len() < 3 {
            return Err(anyhow::anyhow!(
                "Invalid action format: expected at least 3 parts, got {}",
                parts.len()
            ));
        }

        let root_hash = Felt::from_hex_str(parts[0])?;
        let action_type = match parts[1].parse::<u8>()? {
            0 => ActionType::Read,
            1 => ActionType::Write,
            _ => return Err(anyhow::anyhow!("Invalid action type: {}", parts[1])),
        };
        let key = Felt::from_hex_str(parts[2])?;
        let value = if parts.len() > 3 && !parts[3].is_empty() {
            Some(Felt::from_hex_str(parts[3])?)
        } else {
            None
        };

        Ok(Self::new(root_hash, action_type, key, value))
    }
}

/// Trait for tracking actions in the injected state system
pub trait ActionTracker {
    /// Record an action with its type, root hash, key, and optional value
    fn record_action(&mut self, action: Action);

    /// Get all recorded actions as Action objects
    fn get_actions(&self) -> &Vec<Action>;

    /// Clear all recorded actions
    fn clear_actions(&mut self);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_action_serialize_deserialize() {
        // Test Read action
        let read_action = Action::new(
            Felt::from_u128(424242),
            ActionType::Read,
            Felt::from_u128(1234),
            Some(Felt::from_u128(5678)),
        );
        let serialized = read_action.serialize();
        assert_eq!(serialized, "0x0000000000000000000000000000000000000000000000000000000000067932;0;0x00000000000000000000000000000000000000000000000000000000000004D2");

        // Test Write action with value
        let write_action = Action::new(
            Felt::from_u128(424242),
            ActionType::Write,
            Felt::from_u128(1234),
            Some(Felt::from_u128(5678)),
        );
        let serialized = write_action.serialize();
        assert_eq!(serialized, "0x0000000000000000000000000000000000000000000000000000000000067932;1;0x00000000000000000000000000000000000000000000000000000000000004D2;0x000000000000000000000000000000000000000000000000000000000000162E");

        // Test Write action without value
        let write_action_no_val = Action::new(Felt::from_u128(424242), ActionType::Write, Felt::from_u128(1234), None);
        let serialized = write_action_no_val.serialize();
        assert_eq!(serialized, "0x0000000000000000000000000000000000000000000000000000000000067932;1;0x00000000000000000000000000000000000000000000000000000000000004D2");

        // Test deserialization
        let deserialized = Action::deserialize("0x0000000000000000000000000000000000000000000000000000000000067932;1;0x00000000000000000000000000000000000000000000000000000000000004D2;0x000000000000000000000000000000000000000000000000000000000000162E").unwrap();
        assert_eq!(deserialized.root_hash, Felt::from_u128(424242));
        assert_eq!(deserialized.action_type.as_u8(), 1);
        assert_eq!(deserialized.key, Felt::from_u128(1234));
        assert_eq!(deserialized.value, Some(Felt::from_u128(5678)));

        // Test round-trip
        let original = Action::new(Felt::from_u128(424242), ActionType::Read, Felt::from_u128(1234), None);
        let serialized = original.serialize();
        let deserialized = Action::deserialize(&serialized).unwrap();
        assert_eq!(original.root_hash, deserialized.root_hash);
        assert_eq!(original.action_type.as_u8(), deserialized.action_type.as_u8());
        assert_eq!(original.key, deserialized.key);
        assert_eq!(original.value, deserialized.value);
    }
}
