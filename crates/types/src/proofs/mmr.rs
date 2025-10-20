use alloy::primitives::Bytes;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash, Default)]
#[serde_as]
pub struct MmrMeta {
    #[serde(deserialize_with = "deserialize_bytes_even")]
    pub id: Bytes,
    pub size: u64,
    #[serde(deserialize_with = "deserialize_bytes_even")]
    pub root: Bytes,
    #[serde(deserialize_with = "deserialize_vec_bytes_even")]
    pub peaks: Vec<Bytes>,
    pub chain_id: u128,
}

#[derive(thiserror::Error, Debug)]
pub enum MmrMetaError {
    #[error(transparent)]
    SerdeJson(#[from] serde_json::Error),
}

// Accept odd-length hex strings by padding a leading '0' before decoding to Bytes.
// This makes deserialization robust for Poseidon proofs where leading zeros may be omitted.
fn deserialize_bytes_even<'de, D>(deserializer: D) -> Result<Bytes, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let s: String = String::deserialize(deserializer)?;
    let clean = s.trim_start_matches("0x");
    let normalized = if clean.len() % 2 == 1 {
        format!("0{}", clean)
    } else {
        clean.to_string()
    };
    let decoded = alloy::hex::decode(&normalized).map_err(|e| serde::de::Error::custom(format!("Invalid hex string: {}", e)))?;
    Ok(decoded.into())
}

fn deserialize_vec_bytes_even<'de, D>(deserializer: D) -> Result<Vec<Bytes>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let hex_strings: Vec<String> = Vec::deserialize(deserializer)?;
    let mut out = Vec::with_capacity(hex_strings.len());
    for s in hex_strings {
        let clean = s.trim_start_matches("0x");
        let normalized = if clean.len() % 2 == 1 {
            format!("0{}", clean)
        } else {
            clean.to_string()
        };
        let decoded = alloy::hex::decode(&normalized).map_err(|e| serde::de::Error::custom(format!("Invalid hex string: {}", e)))?;
        out.push(decoded.into());
    }
    Ok(out)
}
