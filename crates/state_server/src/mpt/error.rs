use pathfinder_merkle_tree::tree::GetProofError;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum Error {
    #[error("Failed to execute database query: {0}")]
    Database(#[from] rusqlite::Error),
    #[error("Failed to encode node: {0}")]
    NodeEncoding(#[from] bincode::error::EncodeError),
    #[error("Failed to decode node: {0}")]
    NodeDecoding(#[from] bincode::error::DecodeError),
    #[error("Failed to get connection from pool: {0}")]
    PoolConnection(#[from] r2d2::Error),
    #[error("Failed to get proof:")]
    GetProof(GetProofError),
    #[error("Failed to verify proof: {0}")]
    ProofVerification(#[from] eth_trie::TrieError),
    #[error("Failed to decode rlp: {0}")]
    RlpDecoding(#[from] alloy_rlp::Error),
    #[error("Failed to convert address to Felt: {0}")]
    AddressToFeltConversion(String),
    #[error("MPT decoding error: {0}")]
    MptDecodeError(String),
    #[error("Failed to convert U256 to u64")]
    U256ToU64Conversion,
    #[error("Missing node index")]
    MissingNodeIndex,
    #[error("Leaf not found")]
    LeafNotFound,
    #[error("Failed to get leaf")]
    FailedToGetLeaf,
    #[error("Failed to parse hex string: {0}")]
    HexParsing(#[from] hex::FromHexError),
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("Pool creation error: {0}")]
    Pool(r2d2::Error),
    #[error(transparent)]
    Any(#[from] anyhow::Error),
}
