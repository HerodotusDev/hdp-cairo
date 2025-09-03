use clap::Parser;
use state_server::{create_router, AppState};
use tokio::net::TcpListener;
use tracing::info;
use tracing_subscriber::EnvFilter;

/// Binds to the given host and port and starts the axum server.
pub async fn start_server(port: u16, host: &str, db_root_path: &str) -> anyhow::Result<()> {
    // Initialize the logger/subscriber.
    tracing_subscriber::fmt().with_env_filter(EnvFilter::from_default_env()).init();

    let state = AppState::new(db_root_path)?;
    let app = create_router(state);
    let addr = format!("{}:{}", host, port);

    info!("🚀 Server listening on {}", addr);

    let listener = TcpListener::bind(&addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

/// A stateful API server for managing HDP modules injected states.
#[derive(Parser, Debug)]
struct Args {
    /// The port number to listen on
    #[arg(short, long, default_value_t = 3000)]
    port: u16,

    /// The host address to bind to
    #[arg(long, default_value = "0.0.0.0")]
    host: String,

    /// The path to the database root folder
    #[arg(long, default_value = "db")]
    db_root_path: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args = Args::parse();

    if let Err(e) = start_server(args.port, &args.host, &args.db_root_path).await {
        eprintln!("💥 Server failed to start: {}", e);
        return Err(e);
    }

    Ok(())
}
