use axum::Json;
use dry_hint_processor::syscall_handler::SyscallHandler;
use types::ChainProofs;

pub async fn root(Json(value): Json<SyscallHandler>) -> Json<Vec<ChainProofs>> {
    todo!()
}
