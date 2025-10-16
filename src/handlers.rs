use askama::Template;
use axum::{
    body::Body,
    extract::State,
    http::{Uri, header},
    response::{Html, IntoResponse, Response},
};
use r2d2_oracle::{OracleConnectionManager, r2d2::Pool};
use rust_embed::Embed;
use tracing::{error, trace};

use crate::db;
use crate::templates::{ErrorTemplate, StatsDashboard};

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
        None => error_template().await.into_response(),
    }
}

pub async fn error_template() -> impl IntoResponse {
    trace!("handlers::error_template initialized");

    let error_template = ErrorTemplate {};
    Html(
        error_template
            .render()
            .expect("Error rendering error template"),
    )
    .into_response()
}

pub async fn stats_dashboard(State(state): State<AppState>) -> impl IntoResponse {
    trace!("handlers::stats_dashboard initialized");

    let data = match db::fetch_stats_dashboard_json(&state.db_connection_pool) {
        Ok(payload) => payload,
        Err(err) => {
            error!(
                error = %err,
                error_chain = ?err,
                "Failed to load stats dashboard data"
            );
            return error_template().await.into_response();
        }
    };

    let stats_dashboard = StatsDashboard { data };

    match stats_dashboard.render() {
        Ok(html) => Html(html).into_response(),
        Err(err) => {
            error!(error = %err, "Failed to render stats dashboard template");
            error_template().await.into_response()
        }
    }
}
