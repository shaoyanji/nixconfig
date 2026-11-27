---
name: aria2-queue-download
description: "Queue a download on frieren's aria2 daemon via JSON-RPC."
version: 0.1.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: ['aria2', 'download', 'jsonrpc', 'frieren', 'huggingface']
    related_skills: ['burgernas', 'nixconfig-secrets']
---

# aria2-queue-download — queue a download on frieren's aria2 daemon

frieren runs a systemd `aria2-daemon` (downloadDir `/srv/data/downloads`),
reachable as `aria2.frieren.lan`. Downloads are queued and polled over its
JSON-RPC endpoint on **loopback `127.0.0.1:6800/jsonrpc`** with a secret token.
Use this instead of `aria2c` on the CLI: a queued task keeps running under the
daemon and survives your shell, and it is the fleet's declared download lane.

## Auth — the secret is root-only

The RPC secret lives at `/run/secrets/aria2-rpc-secret`, owned `aria2:aria2`
0400 — a normal read from `devji` is permission-denied. Read it via sudo and
**never print its value**:

```bash
SECRET=$(sudo -n cat /run/secrets/aria2-rpc-secret 2>/dev/null)
[ -z "$SECRET" ] && { echo 'could not read secret'; exit 1; }
```

A stale or empty secret makes `aria2.addUri` answer `{"code":1,"message":"Unauthorized"}`.
If you get that, the secret did not read or the token prefix is missing — do not
retry with a guessed token.

## Build the payload with jq, never inline-curl JSON

URLs carry `&`, `?`, `#` and quotes that break a hand-quoted `curl -d '{...}'`.
Build the params with `jq -cn --arg`, which escapes correctly and keeps the
secret out of the transcript text:

```bash
URL='https://<host>/<owner>/<repo>/resolve/main/<file>'
PAYLOAD=$(jq -cn --arg tok "$SECRET" --arg u "$URL" \
  '{jsonrpc:"2.0",id:"q1",method:"aria2.addUri",params:[("token:"+$tok),[$u],{dir:"/srv/data/downloads"}]}')
curl -s http://127.0.0.1:6800/jsonrpc -H 'Content-Type: application/json' -d "$PAYLOAD" | jq .
```

A success returns `{"result":"<gid>"}` (a 16-hex GID). An error returns
`{"error":{"code":1,"message":"Unauthorized"}}`.

## Verify it is actually downloading

A queued task is not a started task. Poll `aria2.tellStatus` with the GID and
read the byte counts:

```bash
PAYLOAD=$(jq -cn --arg tok "$SECRET" '{jsonrpc:"2.0",id:"s1",method:"aria2.tellStatus",params:[("token:"+$tok),"<gid>"]}')
curl -s http://127.0.0.1:6800/jsonrpc -H 'Content-Type: application/json' -d "$PAYLOAD" | jq .
```

Look for `status:"active"`, `totalLength` > `completedLength`, `errorMessage:null`,
and the `files[0].path`. `totalLength` is in bytes.

## Pitfall — the file lands under a hash name

The daemon saves to `downloadDir/<content-hash>` unless the URL/resolve yields a
real filename; a `resolve/main/<file>.gguf` often lands as `99ccd52a…e752` (a
hash), not the human name. Confirm from `tellStatus` `files[0].path` and rename
after completion (`mv downloadDir/<hash> downloadDir/<real-name>`) so
`sort-downloads.sh` classifies it correctly. Verify the true name from the
source listing before queueing (see references/huggingface-sizes.md).

## Destructive-action note

Pushing, sending, or re-pinning nothing here — but if a later step uploads the
download or deploys it, that is a destructive/publish action and goes through
`confirm-before-destructive`.

Related: `burgernas` (Transmission on the Synology cold vault — a different
download lane), `nixconfig-secrets` (where the secret is declared), and
`references/huggingface-sizes.md` (resolve real file names and byte sizes).

Truth: `modules/services/aria2-daemon.nix` — the daemon unit and RPC endpoint; this page is the queue procedure.
