use anyhow::Result;

/// Utility functions for working with merkle trees in the state server context
pub struct TrieUtils;

impl TrieUtils {
    /// Validates that a key is in the correct format for trie operations
    pub fn validate_key(key: &str) -> Result<()> {
        if key.is_empty() {
            return Err(anyhow::anyhow!("Key cannot be empty"));
        }

        if key.starts_with("0x") || key.starts_with("0X") {
            // Validate hex string
            if key.len() < 3 {
                return Err(anyhow::anyhow!("Hex key too short"));
            }
            let hex_part = &key[2..];
            if !hex_part.chars().all(|c| c.is_ascii_hexdigit()) {
                return Err(anyhow::anyhow!("Invalid hex characters in key"));
            }
        } else {
            // Validate decimal number
            key.parse::<u64>()
                .map_err(|_| anyhow::anyhow!("Key must be a valid hex string or decimal number"))?;
        }

        Ok(())
    }

    /// Validates that a value is in the correct format for trie operations
    pub fn validate_value(value: &str) -> Result<()> {
        if value.is_empty() {
            return Err(anyhow::anyhow!("Value cannot be empty"));
        }

        if value.starts_with("0x") || value.starts_with("0X") {
            // Validate hex string
            if value.len() < 3 {
                return Err(anyhow::anyhow!("Hex value too short"));
            }
            let hex_part = &value[2..];
            if !hex_part.chars().all(|c| c.is_ascii_hexdigit()) {
                return Err(anyhow::anyhow!("Invalid hex characters in value"));
            }
        } else {
            // Validate decimal number
            value
                .parse::<u64>()
                .map_err(|_| anyhow::anyhow!("Value must be a valid hex string or decimal number"))?;
        }

        Ok(())
    }

    /// Converts a string to a normalized hex string representation
    pub fn to_hex_string(s: &str) -> Result<String> {
        if s.starts_with("0x") || s.starts_with("0X") {
            Ok(s.to_lowercase())
        } else {
            let num = s.parse::<u64>().map_err(|_| anyhow::anyhow!("Invalid number format"))?;
            Ok(format!("0x{:x}", num))
        }
    }

    /// Validates both key and value formats
    pub fn validate_key_value(key: &str, value: &str) -> Result<()> {
        Self::validate_key(key)?;
        Self::validate_value(value)?;
        Ok(())
    }
}

/// Configuration for trie operations
#[derive(Debug, Clone)]
pub struct TrieConfig {
    /// Maximum number of concurrent operations allowed
    pub max_concurrent_ops: usize,
    /// Default timeout for trie operations in milliseconds
    pub operation_timeout_ms: u64,
}

impl Default for TrieConfig {
    fn default() -> Self {
        Self {
            max_concurrent_ops: 100,
            operation_timeout_ms: 5000,
        }
    }
}

/// Statistics about a trie
#[derive(Debug, Clone, serde::Serialize)]
pub struct TrieStats {
    pub root_hash: String,
    pub estimated_size: u64,
    pub last_updated: Option<String>,
}

impl TrieStats {
    pub fn new(root_hash: String, size: u64) -> Self {
        Self {
            root_hash,
            estimated_size: size,
            last_updated: Some(chrono::Utc::now().to_rfc3339()),
        }
    }

    pub fn empty() -> Self {
        Self {
            root_hash: "0x0000000000000000000000000000000000000000000000000000000000000000".to_string(),
            estimated_size: 0,
            last_updated: Some(chrono::Utc::now().to_rfc3339()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_key() {
        // Test hex keys
        assert!(TrieUtils::validate_key("0x1").is_ok());
        assert!(TrieUtils::validate_key("0X1").is_ok());
        assert!(TrieUtils::validate_key("0x123abc").is_ok());

        // Test decimal keys
        assert!(TrieUtils::validate_key("42").is_ok());
        assert!(TrieUtils::validate_key("0").is_ok());

        // Test invalid keys
        assert!(TrieUtils::validate_key("0xgg").is_err());
        assert!(TrieUtils::validate_key("invalid").is_err());
        assert!(TrieUtils::validate_key("").is_err());
    }

    #[test]
    fn test_validate_value() {
        // Test hex values
        assert!(TrieUtils::validate_value("0x1").is_ok());
        assert!(TrieUtils::validate_value("0X1").is_ok());
        assert!(TrieUtils::validate_value("0x123abc").is_ok());

        // Test decimal values
        assert!(TrieUtils::validate_value("42").is_ok());
        assert!(TrieUtils::validate_value("0").is_ok());

        // Test invalid values
        assert!(TrieUtils::validate_value("0xgg").is_err());
        assert!(TrieUtils::validate_value("invalid").is_err());
        assert!(TrieUtils::validate_value("").is_err());
    }

    #[test]
    fn test_to_hex_string() {
        assert_eq!(TrieUtils::to_hex_string("42").unwrap(), "0x2a");
        assert_eq!(TrieUtils::to_hex_string("0x42").unwrap(), "0x42");
        assert_eq!(TrieUtils::to_hex_string("0X42").unwrap(), "0x42");
        assert!(TrieUtils::to_hex_string("invalid").is_err());
    }

    #[test]
    fn test_validate_key_value() {
        assert!(TrieUtils::validate_key_value("0x1", "0x42").is_ok());
        assert!(TrieUtils::validate_key_value("42", "100").is_ok());
        assert!(TrieUtils::validate_key_value("", "42").is_err());
        assert!(TrieUtils::validate_key_value("42", "").is_err());
    }
}
