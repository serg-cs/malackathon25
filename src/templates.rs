use askama::Template;
use serde_json::Value;

#[derive(Template)]
#[template(path = "pages/error.html")]
pub struct ErrorTemplate {}

#[derive(Template)]
#[template(path = "index.html")]
pub struct StatsDashboard {
    pub data: Value,
}
