//! The gate: edit → diff over a real socket.
//!
//! `bench --core` times apply → ripple → encode, which no coalescer window can
//! be blamed for and which is therefore about twenty times faster than what an
//! editor feels. This measures the segment an editor feels: the server runs on a
//! loopback port, each edit goes out as a masked client frame, and the clock
//! stops when the diff frame is decoded — coalescer window included, which is
//! the same segment `web/window.mjs` times from the browser and the same 5 ms
//! target. Two instruments, one number.
//!
//! The client is hand-rolled on purpose: it is sixty lines of transport, and a
//! WebSocket client dependency would be a dependency the server itself does not
//! have.

use loom_core::{NewToken, Op, FLAG_WORD};
use loom_srv::session::Session;
use loom_srv::{build_state, coalesce, ws};
use loom_wire::{decode_server_at, encode_op_frame, ServerFrame};
use std::io;
use std::time::{Duration, Instant};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;

const TARGET_MS: f64 = 5.0;
/// The key the RFC's handshake example uses. The server checks the handshake's
/// shape, not what the key means, and this client never reads the accept hash.
const KEY: &str = "dGhlIHNhbXBsZSBub25jZQ==";

fn ms(d: Duration) -> f64 {
    d.as_secs_f64() * 1000.0
}

fn find(hay: &[u8], needle: &[u8]) -> Option<usize> {
    hay.windows(needle.len()).position(|w| w == needle)
}

/// Every frame in a message, in order. The server packs what it wrote in one
/// instant into one message, so a message is a sequence, not a frame.
fn walk(msg: &[u8]) -> Vec<ServerFrame> {
    let mut out = Vec::new();
    let mut at = 0;
    while at < msg.len() {
        match decode_server_at(&msg[at..]) {
            Ok((frame, used)) if used > 0 => {
                out.push(frame);
                at += used;
            }
            _ => break,
        }
    }
    out
}

struct Client {
    sock: TcpStream,
    buf: Vec<u8>,
    body: Vec<u8>,
}

/// Zero would be the identity mask, but a client key the server could refuse is
/// not worth the two lines it saves: mask for real.
const MASK: [u8; 4] = [0x37, 0xfa, 0x21, 0x3d];

fn trace(what: &str) {
    if std::env::var("LOOM_DEBUG").is_ok() {
        eprintln!("debug: {what}");
    }
}

impl Client {
    async fn connect(port: u16) -> io::Result<Client> {
        let mut sock = TcpStream::connect(("127.0.0.1", port)).await?;
        // The shipped server sets this for the same reason: an ack and its diff
        // are small writes in a row, and with Nagle on the second waits.
        sock.set_nodelay(true)?;
        let head = format!(
            "GET /ws HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nUpgrade: websocket\r\n\
             Connection: Upgrade\r\nSec-WebSocket-Key: {KEY}\r\nSec-WebSocket-Version: 13\r\n\r\n"
        );
        sock.write_all(head.as_bytes()).await?;
        let mut client = Client {
            sock,
            buf: Vec::new(),
            body: Vec::new(),
        };
        let mut chunk = [0u8; 8192];
        loop {
            if let Some(i) = find(&client.buf, b"\r\n\r\n") {
                let status = String::from_utf8_lossy(&client.buf[..i]).to_string();
                if !status.starts_with("HTTP/1.1 101") {
                    return Err(io::Error::new(io::ErrorKind::InvalidData, status));
                }
                // The snapshot can arrive in the same read as the handshake.
                client.buf.drain(..i + 4);
                return Ok(client);
            }
            let n = client.sock.read(&mut chunk).await?;
            if n == 0 {
                return Err(io::Error::new(
                    io::ErrorKind::UnexpectedEof,
                    "the server closed during the handshake",
                ));
            }
            client.buf.extend_from_slice(&chunk[..n]);
        }
    }

    async fn fill(&mut self, need: usize) -> io::Result<()> {
        let mut chunk = [0u8; 16384];
        while self.buf.len() < need {
            let n = self.sock.read(&mut chunk).await?;
            if n == 0 {
                return Err(io::Error::new(
                    io::ErrorKind::UnexpectedEof,
                    "the socket closed mid-message",
                ));
            }
            self.buf.extend_from_slice(&chunk[..n]);
        }
        Ok(())
    }

    /// One whole message, reassembled from however many transport frames it
    /// took, with that count: a snapshot larger than tungstenite's write buffer
    /// is fragmented, and the number is what says whether a message was split.
    async fn message(&mut self) -> io::Result<(Vec<u8>, usize)> {
        self.body.clear();
        let mut parts = 0usize;
        loop {
            self.fill(2).await?;
            let b0 = self.buf[0];
            let b1 = self.buf[1];
            trace(&format!(
                "frame head {:02x} {:02x}, {} bytes buffered",
                b0,
                b1,
                self.buf.len()
            ));
            let fin = b0 & 0x80 != 0;
            let opcode = b0 & 0x0f;
            let masked = b1 & 0x80 != 0;
            let mut head = 2usize;
            // The transport's own lengths are network order, per the RFC; only
            // the payload behind them is this project's little-endian protocol.
            let len = match (b1 & 0x7f) as usize {
                126 => {
                    self.fill(4).await?;
                    head += 2;
                    u16::from_be_bytes([self.buf[2], self.buf[3]]) as usize
                }
                127 => {
                    self.fill(10).await?;
                    head += 8;
                    u64::from_be_bytes(self.buf[2..10].try_into().unwrap()) as usize
                }
                n => n,
            };
            let mask_at = head;
            if masked {
                head += 4;
            }
            self.fill(head + len).await?;
            let mut payload = self.buf[head..head + len].to_vec();
            if masked {
                let key = [
                    self.buf[mask_at],
                    self.buf[mask_at + 1],
                    self.buf[mask_at + 2],
                    self.buf[mask_at + 3],
                ];
                for (i, byte) in payload.iter_mut().enumerate() {
                    *byte ^= key[i & 3];
                }
            }
            self.buf.drain(..head + len);
            parts += 1;
            match opcode {
                0x8 => {
                    return Err(io::Error::new(io::ErrorKind::ConnectionAborted, "close frame"))
                }
                0x9 => {
                    self.write_frame(0xA, &payload).await?;
                    continue;
                }
                0xA => continue,
                _ => {}
            }
            self.body.extend_from_slice(&payload);
            if fin {
                return Ok((std::mem::take(&mut self.body), parts));
            }
        }
    }

    async fn write_frame(&mut self, opcode: u8, payload: &[u8]) -> io::Result<()> {
        let mut out = Vec::with_capacity(payload.len() + 14);
        out.push(0x80 | opcode);
        match payload.len() {
            n if n < 126 => out.push(0x80 | n as u8),
            n if n <= u16::MAX as usize => {
                out.push(0x80 | 126);
                out.extend_from_slice(&(n as u16).to_be_bytes());
            }
            n => {
                out.push(0x80 | 127);
                out.extend_from_slice(&(n as u64).to_be_bytes());
            }
        }
        // A zero mask is the identity, and the server does not test the key's
        // entropy — only that a client frame is masked at all.
        out.extend_from_slice(&MASK);
        for (i, byte) in payload.iter().enumerate() {
            out.push(byte ^ MASK[i & 3]);
        }
        self.sock.write_all(&out).await
    }
}

fn pct(samples: &[u128], q: f64) -> f64 {
    if samples.is_empty() {
        return 0.0;
    }
    let mut s = samples.to_vec();
    s.sort_unstable();
    s[(((s.len() - 1) as f64) * q).round() as usize] as f64 / 1000.0
}

fn show(name: &str, samples: &[u128]) -> String {
    format!(
        "  {name} p50 {:.2} · p99 {:.2} · max {:.2} ms",
        pct(samples, 0.50),
        pct(samples, 0.99),
        pct(samples, 1.0)
    )
}

pub async fn measure(doc: &str, edits: usize, window_ms: u64, relax: bool) -> i32 {
    let (state, ops_rx) = build_state(Session::with_doc(doc), None, window_ms);
    tokio::spawn(coalesce(ops_rx, state.clone()));
    let listener = match tokio::net::TcpListener::bind(("127.0.0.1", 0)).await {
        Ok(l) => l,
        Err(e) => {
            eprintln!("loom-cli: cannot bind a loopback port: {e}");
            return 1;
        }
    };
    let port = match listener.local_addr() {
        Ok(a) => a.port(),
        Err(e) => {
            eprintln!("loom-cli: no local address: {e}");
            return 1;
        }
    };
    trace(&format!("bound 127.0.0.1:{port}"));
    tokio::spawn(async move {
        let _ = axum::serve(listener, ws::app(state)).tcp_nodelay(true).await;
    });

    let started = Instant::now();
    let mut client = match Client::connect(port).await {
        Ok(c) => c,
        Err(e) => {
            eprintln!("loom-cli: cannot reach the server it just started: {e}");
            return 1;
        }
    };
    let opened = started.elapsed();
    trace(&format!(
        "connected in {:.2} ms, {} bytes already past the headers",
        ms(opened),
        client.buf.len()
    ));
    let (snap_msg, snap_frames) = match client.message().await {
        Ok(m) => m,
        Err(e) => {
            eprintln!("loom-cli: no snapshot: {e}");
            return 1;
        }
    };
    let snap_at = started.elapsed();
    trace(&format!("snapshot {} bytes after {:.2} ms", snap_msg.len(), ms(snap_at)));
    let (revision, tokens) = match walk(&snap_msg).first() {
        Some(ServerFrame::Snapshot { revision, tokens, .. }) => (*revision, tokens.len()),
        other => {
            eprintln!("loom-cli: the first message was not a snapshot: {other:?}");
            return 1;
        }
    };

    let mut at = tokens;
    let mut seq = 1u64;
    let mut latencies: Vec<u128> = Vec::with_capacity(edits);
    let mut acks: Vec<u128> = Vec::with_capacity(edits);
    let mut shared = 0usize;
    // The snapshot's message is one frame, whatever the document's size: it is
    // written before the packing loop, so packing cannot carry or split it.
    let mut max_packed = walk(&snap_msg).len();

    for _ in 0..edits {
        let op = Op::Insert {
            seq,
            offset: at as u32,
            tokens: vec![NewToken {
                flags: FLAG_WORD,
                tag: 0,
                text: b"z".to_vec(),
            }],
        };
        seq += 1;
        at += 1;
        let bytes = match encode_op_frame(&op) {
            Ok(b) => b,
            Err(e) => {
                eprintln!("loom-cli: cannot encode an op: {e}");
                return 1;
            }
        };
        let t0 = Instant::now();
        if let Err(e) = client.write_frame(0x2, &bytes).await {
            eprintln!("loom-cli: the edit did not go out: {e}");
            return 1;
        }
        trace(&format!("op {} sent", op.seq()));
        let mut acked: Option<Instant> = None;
        loop {
            let (msg, _) = match client.message().await {
                Ok(m) => m,
                Err(e) => {
                    eprintln!("loom-cli: the answer did not arrive: {e}");
                    return 1;
                }
            };
            let t = Instant::now();
            let frames = walk(&msg);
            trace(&format!("message {} bytes, {} frames", msg.len(), frames.len()));
            max_packed = max_packed.max(frames.len());
            let mut diff: Option<Instant> = None;
            for frame in &frames {
                match frame {
                    ServerFrame::Ack { seq: s, .. } if *s == op.seq() => acked = Some(t),
                    ServerFrame::Diff { .. } => diff = Some(t),
                    _ => {}
                }
            }
            if let Some(diff) = diff {
                latencies.push(diff.duration_since(t0).as_micros());
                let ack = acked.unwrap_or(diff);
                acks.push(ack.duration_since(t0).as_micros());
                if acked == Some(t) {
                    shared += 1;
                }
                break;
            }
        }
    }

    println!(
        "window {window_ms} ms · revision {revision} · {tokens} tokens · snapshot {} bytes \
         in {snap_frames} ws frame(s), {:.2} ms from connect (socket opened at {:.2} ms)",
        snap_msg.len(),
        ms(snap_at),
        ms(opened)
    );
    if edits == 0 {
        return 0;
    }
    println!("{}", show("single edit → ack ", &acks));
    println!("{}\n  (n={edits}, window included)", show("single edit → diff", &latencies));
    println!("  frames per message: max {max_packed}");
    println!("  the diff shared the ack's message in {shared}/{edits} edits");

    let p99 = pct(&latencies, 0.99);
    let ok = p99 <= TARGET_MS;
    println!(
        "edit → diff p99 {p99:.2} ms vs target {TARGET_MS:.2} ms: {}",
        if ok { "PASS" } else { "FAIL" }
    );
    if !ok && !relax {
        eprintln!("FAIL: edit → diff p99 is {p99:.2} ms, over the {TARGET_MS} ms target");
        return 1;
    }
    0
}
