use r2d2_oracle::{OracleConnectionManager, r2d2::Pool};
use std::env;
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
