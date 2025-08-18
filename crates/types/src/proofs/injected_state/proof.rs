use alloy::primitives::Bytes;
use alloy_rlp::RlpEncodable;
use serde::{Deserialize, Serialize};
use serde_with::serde_as;

const MPT_CHUNK_SIZE: usize = 8;
type MptChunk = [u8; MPT_CHUNK_SIZE];

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Eq, Hash, RlpEncodable)]
#[serde_as]
pub struct MPTProof(pub Vec<Bytes>);

impl MPTProof {
    pub fn new(proof: Vec<Bytes>) -> Self {
        Self(proof)
    }
}

#[serde_as]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MPTProofCairo {
    #[serde_as(as = "Vec<Vec<serde_with::hex::Hex<serde_with::formats::Lowercase>>>")]
    pub nodes: Vec<Vec<MptChunk>>,
    pub bytes_lens: Vec<u64>,
}

// Convert a MPTProof into cairo friendly format
impl From<MPTProof> for MPTProofCairo {
    fn from(proof: MPTProof) -> Self {
        let (proof_cairo, bytes_lens): (Vec<Vec<MptChunk>>, Vec<u64>) = proof
            .0
            .into_iter()
            .map(|node_bytes| {
                let len = node_bytes.len() as u64;
                let chunks = node_bytes
                    .chunks(MPT_CHUNK_SIZE)
                    .map(|chunk| {
                        let mut chunk_array = [0u8; MPT_CHUNK_SIZE];
                        chunk_array[..chunk.len()].copy_from_slice(chunk);
                        chunk_array.reverse();
                        chunk_array
                    })
                    .collect::<Vec<MptChunk>>();
                (chunks, len)
            })
            .unzip();

        Self {
            nodes: proof_cairo,
            bytes_lens,
        }
    }
}
