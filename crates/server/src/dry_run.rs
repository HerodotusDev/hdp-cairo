use axum::Json;
use dry_hint_processor::syscall_handler::SyscallHandler;
use types::HDPDryRunInput;

pub async fn root(Json(value): Json<HDPDryRunInput>) -> Json<SyscallHandler> {
    todo!()
}
