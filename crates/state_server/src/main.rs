// main.rs

use std::error::Error;

use clap::Parser;
use state_server::create_router;
use tokio::net::TcpListener;
use tracing::info;

/// Binds to the given host and port and starts the axum server.
pub async fn start_server(port: u16, host: &str) -> anyhow::Result<()> {
    // Initialize the logger/subscriber.
    tracing_subscriber::fmt::init();

    let app = create_router();
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
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // `clap` parses arguments and automatically handles help/version flags.
    let args = Args::parse();

    // Call the server startup function with parsed arguments.
    if let Err(e) = start_server(args.port, &args.host).await {
        // Use a basic eprintln for the final error as tracing might not be initialized.
        eprintln!("💥 Server failed to start: {}", e);
        return Err(e.into());
    }

    Ok(())
}
