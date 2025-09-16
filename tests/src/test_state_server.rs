use state_server::{create_router, AppState};
use tokio::{net::TcpListener, sync::oneshot};
use tracing::warn;

pub struct TestStateServer {
    pub(crate) server_handle: tokio::task::JoinHandle<()>,
    pub port: u16,
}

impl TestStateServer {
    pub async fn start() -> anyhow::Result<Self> {
        let listener = TcpListener::bind("127.0.0.1:0").await?;
        let port = listener.local_addr()?.port();
        let (ready_tx, ready_rx) = oneshot::channel();
        let server_handle = tokio::spawn(async move {
            let app = create_router(AppState::new_memory().unwrap());
            let server = axum::serve(listener, app);
            let _ = ready_tx.send(());
            if let Err(e) = server.await {
                warn!("State server error: {e}");
            }
        });
        ready_rx.await?;
        Ok(TestStateServer { server_handle, port })
    }

    pub fn base_url(&self) -> String {
        format!("http://127.0.0.1:{}", self.port)
    }

    pub fn shutdown(&self) {
        self.server_handle.abort();
    }
}
