use std::collections::HashSet;

use cairo_vm::Felt252;
use indexer::models::BlockHeader;
use reqwest::Url;
use starknet_types_core::felt::FromStrError;
use types::{
    keys::{self, starknet::get_corresponding_rpc_url},
    proofs::{
        header::{HeaderMmrMeta, HeaderProof},
        starknet::{
            header::Header,
            storage::{GetProofOutput, Storage},
        },
    },
};

use super::FlattenedKey;
use crate::FetcherError;

#[derive(Debug, Default)]
pub struct ProofKeys {
    pub header_keys: HashSet<keys::starknet::header::Key>,
    pub storage_keys: HashSet<keys::starknet::storage::Key>,
}

impl ProofKeys {
    pub async fn fetch_header_proof(
        deployed_on_chain_id: u128,
        accumulates_chain_id: u128,
        block_number: u64,
    ) -> Result<HeaderMmrMeta<Header>, FetcherError> {
        let (mmr_proof, meta) = super::ProofKeys::fetch_mmr_proof(deployed_on_chain_id, accumulates_chain_id, block_number).await?;

        let proof = HeaderProof {
            leaf_idx: mmr_proof.element_index,
            mmr_path: mmr_proof
                .siblings_hashes
                .iter()
                .map(|hash| Felt252::from_hex(hash.as_str()))
                .collect::<Result<Vec<Felt252>, FromStrError>>()?,
        };

        match &mmr_proof.block_header {
            BlockHeader::Fields(fields) => {
                let fields = fields
                    .iter()
                    .map(|field| Felt252::from_hex(field))
                    .collect::<Result<Vec<Felt252>, FromStrError>>()?;

                Ok(HeaderMmrMeta {
                    mmr_meta: meta,
                    headers: vec![Header { fields, proof }],
                })
            }
            _ => Err(FetcherError::InternalError("wrong starknet header format".into())),
        }
    }

    pub async fn fetch_storage_proof(key: &keys::starknet::storage::Key) -> Result<Storage, FetcherError> {
        let rpc_url = get_corresponding_rpc_url(key).map_err(|e| FetcherError::InternalError(e.to_string()))?;
        let response = reqwest::Client::new()
            .post(Url::parse(&rpc_url).unwrap())
            .json(&serde_json::json!({
                "jsonrpc": "2.0",
                "method": "pathfinder_getProof",
                "params": [
                    {"block_number": key.block_number},
                    key.address,
                    [key.storage_slot]
                ],
                "id": 1
            }))
            .send()
            .await?;

        let response_text = response.text().await?;

        let json_rpc_response: serde_json::Value =
            serde_json::from_str(&response_text).map_err(|e| FetcherError::JsonDeserializationError(e.to_string()))?;

        let proof = serde_json::from_value::<GetProofOutput>(json_rpc_response["result"].clone()).map_err(|e| {
            println!("Deserialization error: {}", e);
            FetcherError::JsonDeserializationError(e.to_string())
        })?;

        let storage = Storage::new(key.block_number, key.address, vec![key.storage_slot], proof);

        Ok(storage)
    }

    pub fn to_flattened_keys(&self, chain_id: u128) -> HashSet<FlattenedKey> {
        let mut flattened = HashSet::new();

        for key in &self.header_keys {
            if key.chain_id == chain_id {
                flattened.insert(FlattenedKey {
                    chain_id: key.chain_id,
                    block_number: key.block_number,
                });
            }
        }

        for key in &self.storage_keys {
            if key.chain_id == chain_id {
                flattened.insert(FlattenedKey {
                    chain_id: key.chain_id,
                    block_number: key.block_number,
                });
            }
        }

        flattened
    }
}
