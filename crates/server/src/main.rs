#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

use std::time::Duration;

use axum::{
    Json, Router,
    routing::{get, post},
};
use serde_json::{Value, json};
use tokio::{net::TcpListener, signal};
use tower_http::{timeout::TimeoutLayer, trace::TraceLayer};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use utoipa::OpenApi;
use utoipa_swagger_ui::SwaggerUi;

pub mod dry_run;
pub mod error;
pub mod fetch_proofs;
pub mod sound_run;

#[derive(OpenApi)]
#[openapi(paths(dry_run::root, fetch_proofs::root, sound_run::root))]
struct ApiDoc;

#[tokio::main(flavor = "multi_thread", worker_threads = 4)]
async fn main() {
    // Enable tracing.
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| format!("{}=debug,tower_http=debug,axum=trace", env!("CARGO_CRATE_NAME")).into()),
        )
        .with(tracing_subscriber::fmt::layer().without_time())
        .init();

    // Create a regular axum app.
    let app = Router::new()
        .route("/alive", get(alive))
        .route("/dry_run", post(dry_run::root))
        .route("/fetch_proofs", post(fetch_proofs::root))
        .route("/sound_run", post(sound_run::root))
        .layer((
            TraceLayer::new_for_http(),
            // Graceful shutdown will wait for outstanding requests to complete. Add a timeout so
            // requests don't hang forever.
            TimeoutLayer::new(Duration::from_secs(10)),
        ))
        .merge(SwaggerUi::new("/swagger-ui").url("/api-docs/openapi.json", ApiDoc::openapi()));

    // Create a `TcpListener` using tokio.
    let listener = TcpListener::bind("0.0.0.0:3000").await.unwrap();

    // Run the server with graceful shutdown
    axum::serve(listener, app).with_graceful_shutdown(shutdown_signal()).await.unwrap();
}

async fn alive() -> Json<Value> {
    Json(json!({ "status": "alive" }))
}

async fn shutdown_signal() {
    let ctrl_c = async {
        signal::ctrl_c().await.expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }
}

#[cfg(test)]
mod tests {
    use axum::{
        body::Body,
        http::{Request, StatusCode},
    };
    use dry_hint_processor::syscall_handler::SyscallHandler;
    use http_body_util::BodyExt;
    use tower::ServiceExt;
    use types::{ChainProofs, HDPDryRunInput, HDPInput};

    use super::*;

    fn build_test_app() -> Router {
        Router::new()
            .route("/dry_run", post(dry_run::root))
            .route("/fetch_proofs", post(fetch_proofs::root))
            .route("/sound_run", post(sound_run::root))
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
    async fn test_dry_run_endpoint() {
        let app = build_test_app();
        let input = serde_json::json!({
            "params": Option::<()>::None,
            "layout": "starknet_with_keccak",
            "input": serde_json::from_str::<HDPDryRunInput>(
                &std::fs::read_to_string("tests/hdp_input.json").unwrap()
            ).unwrap()
        });

        let response = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/dry_run")
                    .header("Content-Type", "application/json")
                    .body(Body::from(serde_json::to_string(&input).unwrap()))
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::OK);
        let body = axum::body::to_bytes(response.into_body(), usize::MAX).await.unwrap();
        let output: serde_json::Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(
            output,
            serde_json::from_str::<serde_json::Value>(&std::fs::read_to_string("tests/hdp_keys.json").unwrap()).unwrap()
        );
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
    async fn test_fetch_proofs_endpoint() {
        let app = build_test_app();
        let input = serde_json::from_str::<SyscallHandler>(&std::fs::read_to_string("tests/hdp_keys.json").unwrap()).unwrap();

        let response = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/fetch_proofs")
                    .header("Content-Type", "application/json")
                    .body(Body::from(serde_json::to_string(&input).unwrap()))
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::OK);
        let body = axum::body::to_bytes(response.into_body(), usize::MAX).await.unwrap();
        let output: serde_json::Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(
            output,
            serde_json::from_str::<serde_json::Value>(&std::fs::read_to_string("tests/hdp_proofs.json").unwrap()).unwrap()
        );
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
    async fn test_sound_run_endpoint() {
        let app = build_test_app();
        let sub_input = serde_json::from_str::<HDPDryRunInput>(&std::fs::read_to_string("tests/hdp_input.json").unwrap()).unwrap();
        let input = serde_json::json!({
            "params": Option::<()>::None,
            "layout": "starknet_with_keccak",
            "input": HDPInput {
                chain_proofs: serde_json::from_str::<Vec<ChainProofs>>(
                    &std::fs::read_to_string("tests/hdp_proofs.json").unwrap()
                ).unwrap(),
                params: sub_input.params,
                compiled_class: sub_input.compiled_class,
            }
        });

        let response = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/sound_run")
                    .header("Content-Type", "application/json")
                    .body(Body::from(serde_json::to_string(&input).unwrap()))
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(response.status(), StatusCode::OK);
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
    async fn test_pipeline_integration() {
        let app = build_test_app();

        // 1. First dry run
        let sub_input = serde_json::from_str::<HDPDryRunInput>(&std::fs::read_to_string("tests/hdp_input.json").unwrap()).unwrap();
        let dry_run_input = serde_json::json!({
            "params": Option::<()>::None,
            "layout": "starknet_with_keccak",
            "input": sub_input
        });
        let dry_run_response = app
            .clone()
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/dry_run")
                    .header("Content-Type", "application/json")
                    .body(Body::from(serde_json::to_string(&dry_run_input).unwrap()))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(dry_run_response.status(), StatusCode::OK);

        // 2. Then fetch proofs
        let fetch_input =
            serde_json::from_slice::<SyscallHandler>(&dry_run_response.into_body().collect().await.unwrap().to_bytes()).unwrap();
        let fetch_response = app
            .clone()
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/fetch_proofs")
                    .header("Content-Type", "application/json")
                    .body(Body::from(serde_json::to_string(&fetch_input).unwrap()))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(fetch_response.status(), StatusCode::OK);

        // 3. Finally sound run
        let sound_run_input = serde_json::json!({
            "params": Option::<()>::None,
            "layout": "starknet_with_keccak",
            "input": HDPInput {
                chain_proofs: serde_json::from_slice::<Vec<ChainProofs>>(
                    &fetch_response.into_body().collect().await.unwrap().to_bytes()
                ).unwrap(),
                params: sub_input.params,
                compiled_class: sub_input.compiled_class,
            }
        });
        let sound_run_response = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/sound_run")
                    .header("Content-Type", "application/json")
                    .body(Body::from(serde_json::to_string(&sound_run_input).unwrap()))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(sound_run_response.status(), StatusCode::OK);
    }
}
