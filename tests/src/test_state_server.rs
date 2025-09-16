use std::{
    sync::{Arc, OnceLock},
    time::Duration,
};

use state_server::{create_router, AppState};
use tokio::{net::TcpListener, sync::oneshot, time::timeout};
use tracing::{debug, info, warn};

pub struct TestStateServer {
    shutdown_tx: Option<oneshot::Sender<()>>,
    server_handle: Option<tokio::task::JoinHandle<()>>,
    port: u16,
}

impl TestStateServer {
    pub async fn start() -> anyhow::Result<Self> {
        Self::start_on_port(3000).await
    }

    /// Starts a new state server instance on the specified port with memory-only storage.
    pub async fn start_on_port(mut port: u16) -> anyhow::Result<Self> {
        let listener = loop {
            let addr = format!("0.0.0.0:{}", port);
            match timeout(Duration::from_secs(2), TcpListener::bind(&addr)).await {
                Ok(Ok(listener)) => {
                    info!("🧪 Starting test state server on {}", addr);
                    break listener;
                }
                Ok(Err(e)) => {
                    if port == 0 {
                        return Err(anyhow::anyhow!("Failed to bind to any port: {}", e));
                    }
                    warn!("Failed to bind to port {}: {}. Trying to find an available port.", port, e);
                    // Try with port 0 to get any available port
                    port = 0;
                }
                Err(_) => {
                    return Err(anyhow::anyhow!("Timeout while trying to bind to port {}", port));
                }
            }
        };

        let (shutdown_tx, shutdown_rx) = oneshot::channel::<()>();

        let state = AppState::new_memory()?;
        let app = create_router(state);

        let actual_port = listener.local_addr()?.port();

        let server_handle = tokio::spawn(async move {
            let server_future = axum::serve(listener, app);

            tokio::select! {
                result = server_future => {
                    if let Err(e) = result {
                        warn!("State server error: {}", e);
                    }
                }
                _ = shutdown_rx => {
                    debug!("State server received shutdown signal");
                }
            }
        });

        tokio::time::sleep(Duration::from_millis(200)).await;

        let client = reqwest::Client::new();
        let health_check_url = format!("http://0.0.0.0:{}/get_trie_root_node_idx?trie_label=0x0&trie_root=0x0", actual_port);

        let mut retries = 0;
        let max_retries = 10;
        loop {
            match timeout(Duration::from_millis(500), client.get(&health_check_url).send()).await {
                Ok(Ok(_)) => {
                    info!("✅ Test state server is ready on port {} (after {} retries)", actual_port, retries);
                    break;
                }
                Ok(Err(e)) => {
                    retries += 1;
                    if retries >= max_retries {
                        warn!("State server health check failed after {} retries: {}", max_retries, e);
                        break;
                    }
                    debug!("State server not ready yet (retry {}/{}): {}", retries, max_retries, e);
                    tokio::time::sleep(Duration::from_millis(100)).await;
                }
                Err(_) => {
                    retries += 1;
                    if retries >= max_retries {
                        warn!("State server health check timed out after {} retries", max_retries);
                        break;
                    }
                    debug!("State server health check timeout (retry {}/{})", retries, max_retries);
                    tokio::time::sleep(Duration::from_millis(100)).await;
                }
            }
        }

        Ok(TestStateServer {
            shutdown_tx: Some(shutdown_tx),
            server_handle: Some(server_handle),
            port: actual_port,
        })
    }

    /// Returns the port the server is listening on.
    pub fn port(&self) -> u16 {
        self.port
    }

    /// Returns the base URL for the server.
    pub fn base_url(&self) -> String {
        format!("http://127.0.0.1:{}", self.port)
    }

    /// Gracefully shuts down the state server.
    pub async fn shutdown(mut self) -> anyhow::Result<()> {
        info!("🛑 Shutting down test state server on port {}", self.port);

        if let Some(shutdown_tx) = self.shutdown_tx.take() {
            let _ = shutdown_tx.send(());
        }

        if let Some(handle) = self.server_handle.take() {
            match timeout(Duration::from_secs(5), handle).await {
                Ok(Ok(())) => {
                    debug!("State server shut down gracefully");
                }
                Ok(Err(e)) => {
                    warn!("State server task panicked: {}", e);
                }
                Err(_) => {
                    warn!("State server shutdown timed out");
                }
            }
        }

        Ok(())
    }
}

impl Drop for TestStateServer {
    fn drop(&mut self) {
        if self.shutdown_tx.is_some() || self.server_handle.is_some() {
            // Try to send shutdown signal
            if let Some(shutdown_tx) = self.shutdown_tx.take() {
                let _ = shutdown_tx.send(());
            }

            // Note: We can't await the handle here since Drop is not async
            // But the shutdown signal should cause the server to terminate
            if let Some(handle) = self.server_handle.take() {
                handle.abort(); // Force abort the task if it doesn't shut down gracefully
            }
        }
    }
}

static GLOBAL_TEST_SERVER: OnceLock<Arc<tokio::sync::Mutex<Option<TestStateServer>>>> = OnceLock::new();

/// Ensures a global test state server is running and returns its port.
/// This function is safe to call multiple times and from multiple threads.
pub async fn ensure_test_state_server() -> anyhow::Result<u16> {
    let server_holder = GLOBAL_TEST_SERVER.get_or_init(|| Arc::new(tokio::sync::Mutex::new(None)));

    let mut server_guard = server_holder.lock().await;

    if server_guard.is_none() {
        let server = TestStateServer::start().await?;
        let port = server.port();
        *server_guard = Some(server);

        // Give the server a moment to be fully ready after health check
        tokio::time::sleep(Duration::from_millis(100)).await;

        Ok(port)
    } else {
        Ok(server_guard.as_ref().unwrap().port())
    }
}

/// Shuts down the global test state server if it's running.
/// This should only be called after all tests are complete, not during test execution.
pub async fn shutdown_global_test_server() -> anyhow::Result<()> {
    if let Some(holder) = GLOBAL_TEST_SERVER.get() {
        let mut server_guard = holder.lock().await;
        if let Some(server) = server_guard.take() {
            info!("🛑 Shutting down global test state server");
            server.shutdown().await?;
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_state_server_lifecycle() {
        let server = TestStateServer::start().await.unwrap();
        let port = server.port();

        // Test that the server is responding
        let client = reqwest::Client::new();
        let url = format!("http://0.0.0.0:{}/get_trie_root_node_idx?trie_label=0x0&trie_root=0x0", port);
        let response = client.get(&url).send().await.unwrap();

        // Should get a 404 for non-existent trie, but server should be responding
        assert!(response.status().as_u16() == 404 || response.status().is_success());

        server.shutdown().await.unwrap();
    }

    #[tokio::test]
    async fn test_global_server() {
        let port1 = ensure_test_state_server().await.unwrap();
        let port2 = ensure_test_state_server().await.unwrap();

        // Should be the same port since it's the same global server
        assert_eq!(port1, port2);

        shutdown_global_test_server().await.unwrap();
    }
}
