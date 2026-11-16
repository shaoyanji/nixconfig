//! The socket: upgrade, snapshot, then a select loop that reads ops and writes
//! frames on the same task.

use crate::AppState;
use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::State;
use axum::http::header;
use axum::response::{Html, IntoResponse, Response};
use axum::routing::get;
use axum::Router;
use loom_wire::{decode_op, encode_into, ServerFrame};
use std::sync::Arc;
use tokio::sync::broadcast::error::RecvError;

pub const INDEX_HTML: &str = include_str!("../../../web/index.html");
pub const LOOM_JS: &str = include_str!("../../../web/loom.js");

pub fn app(state: Arc<AppState>) -> Router {
    Router::new()
        .route("/", get(index))
        .route("/loom.js", get(script))
        .route("/health", get(health))
        .route("/ws", get(upgrade))
        .with_state(state)
}

async fn index() -> Html<&'static str> {
    Html(INDEX_HTML)
}

async fn script() -> Response {
    let mut headers = axum::http::HeaderMap::new();
    headers.insert(
        header::CONTENT_TYPE,
        axum::http::HeaderValue::from_static("text/javascript; charset=utf-8"),
    );
    (headers, LOOM_JS).into_response()
}

async fn health() -> &'static str {
    "ok"
}

async fn upgrade(ws: WebSocketUpgrade, State(state): State<Arc<AppState>>) -> impl IntoResponse {
    ws.on_upgrade(move |socket| client(socket, state))
}

fn snapshot_frame(state: &AppState) -> Vec<u8> {
    let mut buf = Vec::new();
    if let Ok(s) = state.session.lock() {
        let _ = encode_into(
            &ServerFrame::Snapshot {
                revision: s.rope.revision(),
                reactors: s.reactor_bits(),
                tokens: s.snapshot_tokens(),
            },
            &mut buf,
        );
    }
    buf
}

async fn client(mut socket: WebSocket, state: Arc<AppState>) {
    // Send the snapshot and subscribe inside one session lock: a batch applied
    // between those two steps would be a diff the client never receives.
    let (initial, mut rx) = {
        let buf = snapshot_frame(&state);
        (buf, state.shared.out.subscribe())
    };
    if socket.send(Message::Binary(initial)).await.is_err() {
        return;
    }

    loop {
        tokio::select! {
            msg = socket.recv() => {
                match msg {
                    Some(Ok(Message::Binary(bytes))) => {
                        if let Ok(op) = decode_op(&bytes) {
                            let _ = state.ops_tx.send(vec![op]);
                        }
                    }
                    Some(Ok(Message::Close(_))) | None => break,
                    Some(Err(_)) => break,
                    _ => {}
                }
            }
            ev = rx.recv() => {
                match ev {
                    Ok(bytes) => {
                        if socket.send(Message::Binary(bytes.as_ref().clone())).await.is_err() {
                            break;
                        }
                    }
                    Err(RecvError::Lagged(_)) => {
                        // Diffs are useless once one is missed: resynchronize.
                        if socket.send(Message::Binary(snapshot_frame(&state))).await.is_err() {
                            break;
                        }
                    }
                    Err(RecvError::Closed) => break,
                }
            }
        }
    }
}
