use askama::Template;

#[derive(Template)]
#[template(path = "pages/error404.html")]
pub struct Error404 {}

#[derive(Template)]
#[template(path = "pages/stats-dashboard.html")]
pub struct StatsDashboard {
    pub path: String,
}
