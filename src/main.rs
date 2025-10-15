use anyhow::Result;
use axum::{Router, routing::get};
use std::{env, net::SocketAddr};
use tracing::info;
use tracing_subscriber::EnvFilter;

mod db;
mod handlers;
mod templates;

#[tokio::main]
async fn main() -> Result<()> {
    // Setup tracing
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| format!("{}=debug", env!("CARGO_CRATE_NAME")).into()),
        )
        .init();

    let db_connection_pool = db::setup_db();
    let state = handlers::AppState { db_connection_pool };

    // App router
    let app = Router::new()
        .route("/", get(handlers::stats_dashboard))
        .route("/static/{*file}", get(handlers::static_handler))
        .fallback(handlers::error404)
        .with_state(state);

    // Setup server in open localhost port 8000
    let addr = SocketAddr::from(([0, 0, 0, 0], 8000));
    let listener = tokio::net::TcpListener::bind(addr).await?;
    info!("Starting server...");
    axum::serve(listener, app).await?;

    return Ok(());
}
