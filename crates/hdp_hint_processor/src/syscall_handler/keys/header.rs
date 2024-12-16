use super::FetchValue;
use crate::{
    hint_processor::models::proofs::{
        self,
        header::{Header, HeaderProof},
        mmr::MmrMeta,
    },
    syscall_handler::{utils::SyscallExecutionError, RPC},
};
use alloy::{
    hex::FromHexError,
    primitives::{BlockNumber, Bytes, ChainId},
    providers::{Provider, RootProvider},
    rpc::types::{Block, BlockTransactionsKind},
    transports::http::Http,
};
use cairo_types::traits::CairoType;
use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::memory_errors::MemoryError, vm_core::VirtualMachine},
    Felt252,
};
use provider::indexer::{
    types::{BlockHeader, IndexerQuery, MMRData},
    Indexer,
};
use reqwest::{Client, Url};
use serde::{Deserialize, Serialize};
use starknet_types_core::felt::FromStrError;
use std::env;

#[derive(Debug, Serialize, Deserialize)]
pub struct CairoKey {
    chain_id: Felt252,
    block_number: Felt252,
}

impl CairoType for CairoKey {
    fn from_memory(vm: &VirtualMachine, address: Relocatable) -> Result<Self, MemoryError> {
        Ok(Self {
            chain_id: *vm.get_integer((address + 0)?)?,
            block_number: *vm.get_integer((address + 1)?)?,
        })
    }
    fn to_memory(&self, vm: &mut VirtualMachine, address: Relocatable) -> Result<(), MemoryError> {
        vm.insert_value((address + 0)?, self.chain_id)?;
        vm.insert_value((address + 1)?, self.block_number)?;
        Ok(())
    }
    fn n_fields() -> usize {
        2
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct Key {
    chain_id: ChainId,
    block_number: BlockNumber,
}

impl FetchValue for Key {
    type Value = Block;

    fn fetch_value(&self) -> Result<Self::Value, SyscallExecutionError> {
        let provider = RootProvider::<Http<Client>>::new_http(Url::parse(&env::var(RPC).unwrap()).unwrap());
        let runtime = tokio::runtime::Runtime::new().unwrap();
        let block = runtime
            .block_on(async {
                provider
                    .get_block_by_number(self.block_number.into(), BlockTransactionsKind::Hashes)
                    .await
            })
            .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?
            .ok_or(SyscallExecutionError::InternalError("Block not found".into()))?;
        Ok(block)
    }

    // fn fetch_proof(&self) -> Result<Self::Proof, SyscallExecutionError> {
    //     let provider = Indexer::default();
    //     let runtime = tokio::runtime::Runtime::new().unwrap();

    //     // Fetch proof response
    //     let response = runtime
    //         .block_on(async {
    //             provider
    //                 .get_headers_proof(IndexerQuery::new(self.chain_id, self.block_number, self.block_number))
    //                 .await
    //         })
    //         .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?;

    //     // Extract MMR metadata
    //     let mmr_meta = MmrMeta {
    //         id: response
    //             .mmr_meta
    //             .mmr_id
    //             .parse()
    //             .map_err(|e| SyscallExecutionError::InternalError(format!("{e}").into()))?,
    //         size: response.mmr_meta.mmr_size,
    //         root: response
    //             .mmr_meta
    //             .mmr_root
    //             .parse()
    //             .map_err(|e| SyscallExecutionError::InternalError(format!("{e}").into()))?,
    //         chain_id: self.chain_id,
    //         peaks: response
    //             .mmr_meta
    //             .mmr_peaks
    //             .iter()
    //             .map(|peak| peak.parse())
    //             .collect::<Result<Vec<Bytes>, FromHexError>>()
    //             .map_err(|e| SyscallExecutionError::InternalError(format!("{e}").into()))?,
    //     };

    //     // Retrieve MMR proof
    //     let mmr_proof = response
    //         .headers
    //         .get(&self.block_number)
    //         .ok_or_else(|| SyscallExecutionError::InternalError("block not found".into()))?;

    //     // Parse RLP
    //     let rlp = match &mmr_proof.block_header {
    //         BlockHeader::RlpString(rlp) => rlp,
    //         _ => return Err(SyscallExecutionError::InternalError("wrong rlp format".into())),
    //     };

    //     // Construct Header
    //     let header = Header {
    //         rlp: rlp.parse().map_err(|e| SyscallExecutionError::InternalError(format!("{e}").into()))?,
    //         proof: HeaderProof {
    //             leaf_idx: mmr_proof.element_index,
    //             mmr_path: mmr_proof
    //                 .siblings_hashes
    //                 .iter()
    //                 .map(|hash| hash.parse())
    //                 .collect::<Result<Vec<Bytes>, FromHexError>>()
    //                 .map_err(|e| SyscallExecutionError::InternalError(format!("{e}").into()))?,
    //         },
    //     };

    //     Ok((mmr_meta, header))
    // }
}

impl TryFrom<CairoKey> for Key {
    type Error = SyscallExecutionError;
    fn try_from(value: CairoKey) -> Result<Self, Self::Error> {
        Ok(Self {
            chain_id: value
                .chain_id
                .try_into()
                .map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))?,
            block_number: value
                .block_number
                .try_into()
                .map_err(|e| SyscallExecutionError::InternalError(format!("{}", e).into()))?,
        })
    }
}
