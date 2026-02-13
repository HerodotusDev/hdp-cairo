use std::collections::HashSet;

use alloy::{
    network::Ethereum,
    primitives::Bytes,
    providers::{Provider, RootProvider},
};
use reqwest::Url;
use types::keys::{self, evm::get_corresponding_rpc_url};

use crate::FetcherError;

#[derive(Debug, Default)]
pub struct ProofKeys {
    pub bytecode: HashSet<keys::evm::account::Key>,
}

impl ProofKeys {
    pub async fn fetch_bytecode(key: &keys::evm::account::Key) -> Result<Bytes, FetcherError> {
        let rpc_url = get_corresponding_rpc_url(key).map_err(|e| FetcherError::InternalError(e.to_string()))?;
        let url = Url::parse(&rpc_url).map_err(|e| FetcherError::InternalError(format!("Invalid RPC URL '{rpc_url}': {e}")))?;
        let provider = RootProvider::<Ethereum>::new_http(url);
        provider
            .get_code_at(key.address)
            .block_id(key.block_number.into())
            .await
            .map_err(|e| FetcherError::InternalError(e.to_string()))
    }
}
