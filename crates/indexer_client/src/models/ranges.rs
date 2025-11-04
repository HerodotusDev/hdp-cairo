use std::{collections::HashMap, ops::RangeInclusive};

use serde::{ser::SerializeSeq, Deserialize, Deserializer, Serialize, Serializer};

mod range_inclusive_vec_as_array_vec {
    use super::*;

    pub fn serialize<S>(vec_ranges: &Vec<RangeInclusive<u64>>, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let mut seq = serializer.serialize_seq(Some(vec_ranges.len()))?;
        for range in vec_ranges {
            let arr = [*range.start(), *range.end()];
            seq.serialize_element(&arr)?;
        }
        seq.end()
    }

    pub fn deserialize<'de, D>(deserializer: D) -> Result<Vec<RangeInclusive<u64>>, D::Error>
    where
        D: Deserializer<'de>,
    {
        let vec_of_arrays: Vec<[u64; 2]> = Vec::deserialize(deserializer)?;
        let vec_ranges = vec_of_arrays.into_iter().map(|arr| arr[0]..=arr[1]).collect();
        Ok(vec_ranges)
    }
}

#[derive(Debug, Serialize, Deserialize, Clone, Default)]
pub struct FunctionsRanges {
    /// Serializes to/from `[[u64; 2], ...]`
    #[serde(default, with = "range_inclusive_vec_as_array_vec")]
    pub keccak: Vec<RangeInclusive<u64>>,

    /// Serializes to/from `[[u64; 2], ...]`
    #[serde(default, with = "range_inclusive_vec_as_array_vec")]
    pub poseidon: Vec<RangeInclusive<u64>>,
}

pub type RangesResponse = HashMap<u128, HashMap<u128, FunctionsRanges>>;
