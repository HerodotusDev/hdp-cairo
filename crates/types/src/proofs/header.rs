use alloy::{hex, primitives::Bytes};
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

use super::mmr::MmrMeta;

fn deserialize_mmr_path<'de, D>(deserializer: D) -> Result<Vec<Bytes>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let hex_strings: Vec<String> = Vec::deserialize(deserializer)?;
    let mut bytes_vec = Vec::new();

    for hex_str in hex_strings {
        let clean_hex = hex_str.trim_start_matches("0x");
        let normalized = if clean_hex.len() % 2 == 1 {
            format!("0{}", clean_hex)
        } else {
            clean_hex.to_string()
        };
        let bytes = alloy::hex::decode(&normalized).map_err(|e| serde::de::Error::custom(format!("Invalid hex string: {}", e)))?;
        bytes_vec.push(bytes.into());
    }

    Ok(bytes_vec)
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default, Hash)]
pub struct HeaderMmrMeta<T> {
    pub headers: Vec<T>,
    pub mmr_meta: MmrMeta,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash, Default)]
#[serde_as]
pub struct HeaderProof {
    pub leaf_idx: u64,
    #[serde(deserialize_with = "deserialize_mmr_path")]
    pub mmr_path: Vec<Bytes>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash)]
pub struct HeaderProofSerialized {
    pub leaf_idx: u64,
    pub mmr_path: Vec<String>,
}

impl From<&HeaderProof> for HeaderProofSerialized {
    fn from(proof: &HeaderProof) -> Self {
        let mmr_path: Vec<String> = proof.mmr_path.iter().map(|bytes| format!("0x{}", hex::encode(bytes))).collect();

        HeaderProofSerialized {
            leaf_idx: proof.leaf_idx,
            mmr_path,
        }
    }
}
