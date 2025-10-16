use std::env;

use anyhow::{Context, Result, anyhow};
use r2d2_oracle::{
    OracleConnectionManager,
    oracle::{Error as OracleError, ErrorKind as OracleErrorKind},
    r2d2::Pool,
};
use tracing::{info, trace};

pub fn setup_db() -> Pool<OracleConnectionManager> {
    trace!("db::setup_db initialized");
    info!("Creating DB connection pool...");

    let manager = OracleConnectionManager::new(
        env::var("DB_USER").expect("DB_USER not provided").as_str(),
        env::var("DB_PASS")
            .expect("DATABASE_PASSWORD not provided")
            .as_str(),
        "(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=adb.eu-madrid-1.oraclecloud.com))(connect_data=(service_name=g1e1a7b2277b0d5_malackathon25_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))",
    );

    Pool::builder()
        .max_size(15)
        .build(manager)
        .expect("Error initializing DB connection")
}

pub fn fetch_stats_dashboard_json(pool: &Pool<OracleConnectionManager>) -> Result<serde_json::Value> {
    trace!("db::fetch_stats_dashboard_json initialized");

    let raw_query = include_str!("../database/fetch_stats_dashboard_json.sql");
    let query = raw_query.trim().trim_end_matches(';');

    let conn = pool
        .get()
        .context("Failed to acquire Oracle connection from the pool")?;

    let json_payload: String = conn
        .query_row_as::<String>(query, &[])
        .map_err(|err: OracleError| {
            if err.kind() == OracleErrorKind::NoDataFound {
                anyhow!("Stats dashboard query returned no rows")
            } else {
                err.into()
            }
        })
        .context("Failed to execute stats dashboard query")?;

    let parsed_json = serde_json::from_str::<serde_json::Value>(&json_payload)
        .context("Stats dashboard payload was not valid JSON")?;

    Ok(parsed_json)
}
