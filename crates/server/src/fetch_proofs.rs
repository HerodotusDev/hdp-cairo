use axum::Json;
use dry_hint_processor::syscall_handler::{evm, starknet};
use fetcher::{Fetcher, parse_syscall_handler};
use syscall_handler::SyscallHandler;
use types::ChainProofs;

use crate::error::AppError;

#[utoipa::path(
    get,
    path = "/fetch_proofs",
    request_body = ref("SyscallHandler") // TODO implement ToSchema (big and tedious task impl when explicitly needed)
)]
pub async fn root(
    Json(value): Json<SyscallHandler<evm::CallContractHandler, starknet::CallContractHandler>>,
) -> Result<Json<Vec<ChainProofs>>, AppError> {
    let proof_keys = parse_syscall_handler(value)?;

    let fetcher = Fetcher::new(&proof_keys);
    let (evm_proofs, starknet_proofs) = tokio::try_join!(fetcher.collect_evm_proofs(), fetcher.collect_starknet_proofs())?;
    let chain_proofs = vec![
        ChainProofs::EthereumSepolia(evm_proofs),
        ChainProofs::StarknetSepolia(starknet_proofs),
    ];

    Ok(Json(chain_proofs))
}
