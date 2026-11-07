// The same read path as the Go prototype, on tokio + axum: static bytes served
// from memory, one history frame per connection, and a broadcast channel that
// fans a new turn out to every open stream. Dependencies are the point of the
// comparison as much as the code is.
use axum::{
    extract::State,
    http::{header, HeaderValue, StatusCode},
    response::{
        sse::{Event, Sse},
        IntoResponse, Response,
    },
    routing::{get, post},
    Router,
};
use futures_util::stream::{once, StreamExt};
use serde::Deserialize;
use std::{
    convert::Infallible,
    net::SocketAddr,
    path::{Path, PathBuf},
    sync::{
        atomic::{AtomicU64, Ordering},
        Arc,
    },
    time::{SystemTime, UNIX_EPOCH},
};
use tokio::sync::broadcast;
use tokio_stream::wrappers::BroadcastStream;

#[derive(Clone, Deserialize)]
struct Turn {
    id: String,
    source: String,
    subject: String,
    action: String,
    when: String,
    branch: String,
    commit: String,
}

#[derive(Clone)]
struct Frame {
    data: String,
    bench: Option<String>,
}

struct App {
    history: String,
    turns: Vec<Turn>,
    tx: broadcast::Sender<Frame>,
    seq: AtomicU64,
    index: &'static [u8],
    css: &'static [u8],
    js: &'static [u8],
}

fn esc(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

fn row(t: &Turn) -> String {
    let mut b = String::with_capacity(512);
    b.push_str(&format!(
        r#"<article class="turn" id="turn-{}"><div class="shard" aria-hidden="true"></div><header class="head"><span class="out done">done</span><span class="src">{}</span><span class="when">{}</span></header><h2 class="subject">{}</h2><p class="action">{}</p><div class="meta">"#,
        esc(&t.id),
        esc(&t.source),
        esc(&t.when),
        esc(&t.subject),
        esc(&t.action)
    ));
    if !t.branch.is_empty() {
        b.push_str(&format!(r#"<span class="tag">branch {}</span>"#, esc(&t.branch)));
    }
    if !t.commit.is_empty() {
        b.push_str(&format!(r#"<span class="tag">base {}</span>"#, esc(&t.commit)));
    }
    b.push_str(r#"</div><div class="req"></div></article>"#);
    b
}

async fn index(State(app): State<Arc<App>>) -> Response {
    served(app.index, "text/html; charset=utf-8")
}

async fn css(State(app): State<Arc<App>>) -> Response {
    served(app.css, "text/css")
}

async fn js(State(app): State<Arc<App>>) -> Response {
    served(app.js, "text/javascript")
}

fn served(body: &'static [u8], ctype: &'static str) -> Response {
    let mut res = body.into_response();
    res.headers_mut()
        .insert(header::CONTENT_TYPE, HeaderValue::from_static(ctype));
    res.headers_mut().insert(
        header::CACHE_CONTROL,
        HeaderValue::from_static("no-cache"),
    );
    res
}

async fn stream(
    State(app): State<Arc<App>>,
) -> Sse<impl futures_util::Stream<Item = Result<Event, Infallible>>> {
    let rx = app.tx.subscribe();
    let history = format!(
        "selector #log\nmode inner\nelements {}",
        app.history
    );
    let first = once(async move { Ok::<_, Infallible>(Event::default().event("patch").data(history)) });
    let rest = BroadcastStream::new(rx).filter_map(|msg| async move {
        match msg {
            Ok(frame) => {
                let mut event = Event::default().event("patch").data(frame.data);
                if let Some(bench) = frame.bench {
                    event = event.comment(bench);
                }
                Some(Ok::<_, Infallible>(event))
            }
            Err(_) => None,
        }
    });
    Sse::new(first.chain(rest))
}

/// Bench-only: publish one turn the way the shim relay would.
async fn broadcast(State(app): State<Arc<App>>) -> Response {
    let n = app.seq.fetch_add(1, Ordering::Relaxed) + 1;
    let t = &app.turns[(n as usize) % app.turns.len()];
    let ms = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_millis();
    let frame = Frame {
        data: format!("selector #log\nmode prepend\nelements {}", row(t)),
        bench: Some(format!("bench {} {}", n, ms)),
    };
    let listeners = app.tx.send(frame).unwrap_or(0);
    (
        StatusCode::OK,
        [(header::CONTENT_TYPE, "application/json")],
        format!(r#"{{"seq":{},"clients":{}}}"#, n, listeners),
    )
        .into_response()
}

async fn health(State(app): State<Arc<App>>) -> String {
    app.turns.len().to_string()
}

fn load(path: &Path) -> Vec<u8> {
    std::fs::read(path).unwrap_or_else(|e| panic!("reading {}: {e}", path.display()))
}

#[tokio::main]
async fn main() {
    let mut addr = "127.0.0.1:9101".to_string();
    let mut site = PathBuf::from("modules/services/turns-dashboard/web");
    let mut fixture = PathBuf::from("fixture/turns.json");
    let mut args = std::env::args().skip(1);
    while let Some(a) = args.next() {
        match a.as_str() {
            "-addr" => addr = args.next().expect("-addr needs a value"),
            "-site" => site = PathBuf::from(args.next().expect("-site needs a value")),
            "-fixture" => fixture = PathBuf::from(args.next().expect("-fixture needs a value")),
            other => panic!("unknown flag {other}"),
        }
    }

    let turns: Vec<Turn> =
        serde_json::from_slice(&load(&fixture)).expect("fixture is a JSON array of turns");
    let mut history = String::new();
    for t in &turns {
        history.push_str(&row(t));
    }

    let (tx, _) = broadcast::channel::<Frame>(1024);
    let app = Arc::new(App {
        history,
        turns,
        tx,
        seq: AtomicU64::new(0),
        index: Box::leak(load(&site.join("index.html")).into_boxed_slice()),
        css: Box::leak(load(&site.join("style.css")).into_boxed_slice()),
        js: Box::leak(load(&site.join("app.js")).into_boxed_slice()),
    });

    eprintln!(
        "turns-runtime rust: {addr}, {} turns, {} bytes of history",
        app.turns.len(),
        app.history.len()
    );

    let router = Router::new()
        .route("/", get(index))
        .route("/style.css", get(css))
        .route("/app.js", get(js))
        .route("/api/stream", get(stream))
        .route("/api/broadcast", post(broadcast))
        .route("/healthz", get(health))
        .with_state(app);

    let listener = tokio::net::TcpListener::bind(&addr).await.expect("bind");
    axum::serve(
        listener,
        router.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .await
    .expect("serve");
}
