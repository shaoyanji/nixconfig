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
use tokio::sync::broadcast;
use tokio::sync::broadcast::error::RecvError;

/// Ceiling on a packed message. A frame burst is a few hundred bytes; a client
/// this far behind is owed a snapshot on the next lag, not a megabyte of diffs.
const PACK_LIMIT: usize = 64 * 1024;

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

/// Add every frame already queued for this client to `buf`.
///
/// The ack and the list a retune causes are two frames written microseconds
/// apart. As two messages they cost two writes and two wake-ups, and the second
/// arrives a round trip of scheduling later; packed, the client handles them in
/// one event. Frames are self-delimiting, so the client walks the buffer.
fn pack_queued(rx: &mut broadcast::Receiver<Arc<Vec<u8>>>, buf: &mut Vec<u8>) -> usize {
    let mut packed = 0;
    while buf.len() < PACK_LIMIT {
        match rx.try_recv() {
            Ok(more) => {
                buf.extend_from_slice(&more);
                packed += 1;
            }
            Err(_) => break,
        }
    }
    packed
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
    // The snapshot carries tokens, not spans: the constraint list comes beside
    // it, because a page that connects has no index of its own.
    if let Some(cons) = crate::constraints_frame(&state) {
        if socket.send(Message::Binary(cons)).await.is_err() {
            return;
        }
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
                        let mut message = Vec::with_capacity(bytes.len() + 64);
                        message.extend_from_slice(&bytes);
                        pack_queued(&mut rx, &mut message);
                        if socket.send(Message::Binary(message)).await.is_err() {
                            break;
                        }
                    }
                    Err(RecvError::Lagged(_)) => {
                        // Diffs are useless once one is missed: resynchronize.
                        if socket.send(Message::Binary(snapshot_frame(&state))).await.is_err() {
                            break;
                        }
                        match crate::constraints_frame(&state) {
                            Some(cons) => {
                                if socket.send(Message::Binary(cons)).await.is_err() {
                                    break;
                                }
                            }
                            None => {}

                        }
                    }
                    Err(RecvError::Closed) => break,
                }
            }
        }
    }
}
