use loom_srv::{build_state, coalesce, metrics_ticker, persist, session::Session, ticker, ws};
use std::net::SocketAddr;
use std::path::PathBuf;

const DEMO: &str = "\
the outstanding reconsideration of tokenization is that a merge can ripple past the window, and a reactor that relexes the whole document cannot tell you why it moved.\n\
a piece table keeps the bytes and the reactor bank keeps its own segmentation, so six opinions cost six windows and never six passes.\n\
plant a constraint on a span, then break it and restore it: the feed should not flicker.\n";

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let port: u16 = std::env::var("LOOM_PORT")
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(8787);
    let bind = std::env::var("LOOM_BIND").unwrap_or_else(|_| "127.0.0.1".to_string());
    let coalesce_ms: u64 = std::env::var("LOOM_COALESCE_MS")
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(8);
    let data: Option<PathBuf> = match std::env::var("LOOM_DATA") {
        Ok(v) if v == "off" || v.is_empty() => None,
        Ok(v) => Some(PathBuf::from(v)),
        Err(_) => Some(PathBuf::from("./session")),
    };

    let (sess, replayed, had_snapshot) = match &data {
        Some(dir) => match persist::load(dir) {
            Ok((Some(snap), records)) => {
                let s = persist::restore(&snap, &records, &loom_tok::bpe_a());
                (s, records.len(), true)
            }
            // A log with no snapshot has no known base document, so replaying it
            // would invent one. Seed the demo and pin it below.
            Ok((None, _)) => (Session::with_doc(DEMO), 0, false),
            // A snapshot that exists but does not decode is not a fresh start:
            // starting the demo and appending would drop the document the
            // operator still has on disk, silently. Refuse and say how to get
            // past it.
            Err(e) => {
                eprintln!("loom: refusing to start: {e}");
                eprintln!(
                    "loom: move {} aside to start a new session",
                    dir.join(persist::SNAP_FILE).display()
                );
                std::process::exit(1);
            }
        },
        None => (Session::with_doc(DEMO), 0, false),
    };

    let (tokens, bytes) = (sess.rope.len_tokens(), sess.rope.len_bytes());
    let constraints = sess.constraints.len();
    let (state, ops_rx) = build_state(sess, data.clone(), coalesce_ms);
    tokio::spawn(coalesce(ops_rx, state.clone()));
    tokio::spawn(ticker(state.clone()));
    tokio::spawn(metrics_ticker(state.clone()));

    // Pin the starting document. Without this a first run leaves a log whose
    // ops have no base to replay onto, and a restart comes back as an empty
    // document wearing the edits.
    if !had_snapshot {
        if let Ok(mut guard) = state.persist.lock() {
            if let Some(p) = guard.as_mut() {
                if let Ok(s) = state.session.lock() {
                    if let Err(e) = p.snapshot(&s) {
                        eprintln!("loom: could not pin the base snapshot: {e}");
                    }
                }
            }
        }
    }

    let addr: SocketAddr = format!("{bind}:{port}")
        .parse()
        .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidInput, format!("{e}")))?;
    let listener = tokio::net::TcpListener::bind(addr).await?;
    println!(
        "token loom listening on http://{addr}/ (ws /ws) · {tokens} tokens, {bytes} bytes · {constraints} constraints · replayed {replayed} batches · data {data:?} · coalesce {coalesce_ms}ms"
    );
    axum::serve(listener, ws::app(state)).await
}
