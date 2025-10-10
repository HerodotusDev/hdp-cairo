use state_server::{create_router, AppState};
use tokio::{
    net::{TcpListener, ToSocketAddrs},
    sync::oneshot,
    task::JoinHandle,
};

pub struct TestStateServer {
    server_handle: JoinHandle<Result<(), anyhow::Error>>,
    shutdown_tx: Option<oneshot::Sender<()>>,
    pub port: u16,
}

impl TestStateServer {
    /// Spawns the server in the background and waits until it is ready to accept connections.
    pub async fn start<A: ToSocketAddrs>(addr: A) -> anyhow::Result<Self> {
        let (shutdown_tx, shutdown_rx) = oneshot::channel();

        let listener = TcpListener::bind(addr).await?;
        let port = listener.local_addr()?.port();

        let server_handle = tokio::spawn(async move {
            let app = create_router(AppState::new_memory()?);

            axum::serve(listener, app)
                .with_graceful_shutdown(async {
                    shutdown_rx.await.ok();
                })
                .await?;

            Ok(())
        });

        Ok(TestStateServer {
            server_handle,
            shutdown_tx: Some(shutdown_tx),
            port,
        })
    }

    pub async fn stop(mut self) -> anyhow::Result<()> {
        if let Some(tx) = self.shutdown_tx.take() {
            let _ = tx.send(());
        }
        self.server_handle.await?
    }
}
