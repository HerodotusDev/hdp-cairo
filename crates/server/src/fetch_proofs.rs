use axum::Json;
use dry_hint_processor::syscall_handler::SyscallHandler;
use fetcher::{Fetcher, parse_syscall_handler};
use types::ChainProofs;

use crate::error::AppError;

pub async fn root(Json(value): Json<SyscallHandler>) -> Result<Json<Vec<ChainProofs>>, AppError> {
    let proof_keys = parse_syscall_handler(value)?;

    let fetcher = Fetcher::new(&proof_keys);
    let (evm_proofs, starknet_proofs) = tokio::try_join!(fetcher.collect_evm_proofs(), fetcher.collect_starknet_proofs())?;
    let chain_proofs = vec![
        ChainProofs::EthereumSepolia(evm_proofs),
        ChainProofs::StarknetSepolia(starknet_proofs),
    ];

    Ok(Json(chain_proofs))
}
