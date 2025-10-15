use askama::Template;
use axum::{
    body::Body,
    extract::State,
    http::{Uri, header},
    response::{Html, IntoResponse, Response},
};
use r2d2_oracle::{OracleConnectionManager, r2d2::Pool};
use rust_embed::Embed;
use tracing::trace;

use crate::templates::{Error404, StatsDashboard};

#[derive(Clone)]
pub struct AppState {
    pub db_connection_pool: Pool<OracleConnectionManager>,
}

#[derive(Embed)]
#[folder = "static/"]
struct StaticFile;

pub async fn static_handler(uri: Uri) -> impl IntoResponse {
    trace!("handlers::static_handler initialized");

    let path = uri.path().trim_start_matches("/static/");

    match StaticFile::get(path) {
        Some(file) => {
            let mime = mime_guess::from_path(path).first_or_octet_stream();

            Response::builder()
                .header(header::CONTENT_TYPE, mime.as_ref())
                .body(Body::from(file.data))
                .unwrap()
        }
        None => error404().await.into_response(),
    }
}

pub async fn error404() -> impl IntoResponse {
    trace!("handlers::error404 initialized");

    let error404_template = Error404 {};
    Html(
        error404_template
            .render()
            .expect("Error rendering error404 template"),
    )
    .into_response()
}

pub async fn stats_dashboard(uri: Uri, State(state): State<AppState>) -> impl IntoResponse {
    trace!("handlers::stats_dashboard initialized");
    let path = uri.path().to_string();

    let stats_dashboard = StatsDashboard { path };

    Html(
        stats_dashboard
            .render()
            .expect("Error rendering stats_dashboard template"),
    )
    .into_response()
}
