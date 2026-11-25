#!/usr/bin/env bash
# image-gen.sh — one prompt in, one JSON line out, uploaded, detachable.
#
#   PROMPT='...' bash image-gen.sh                    # {"id","url","path","size","prompt"}
#   PROMPT='...' DETACH=1 bash image-gen.sh           # starts a unit, prints {"unit","log","path"}
#   PROMPTS=/tmp/list.txt bash image-gen.sh --batch   # one prompt per line, JSONL at OUTDIR/index.jsonl
#
# WHY THIS EXISTS: the Go client already prints the delivery URL with `--json`,
# but reaching it by hand means remembering the size flag, the output flag, the
# session refresh and the 60-second token. Those are the caller's whole job here,
# so a prompt can be piped, backgrounded and consumed by jq without a human in
# the loop. `cpg` stays the transport; nothing below re-implements auth.
#
# The URL the CLI prints is session-gated — a bare fetch answers 401 — so the
# render is uploaded to Cloudinary before its URL is reported, and `.url` is the
# delivery URL a page can actually use. `UPLOAD=0` keeps a throwaway render local.
#
# The auth dance, the bank upload, the batch loop and the detach now live in
# tools/os (verbs gen, gen-batch, gen-detach); this shim keeps the env contract.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/image-daily-lib.sh"
SIZE=${SIZE:-1536x1024}
DETACH=${DETACH:-0}
cli=$(image_daily_cli)

if [ "${1:-}" = "--batch" ]; then
  exec "$cli" gen-batch --repo "$repo" --root "$IMAGES_ROOT" --size "$SIZE"
fi
if [ "$DETACH" = "1" ]; then
  exec "$cli" gen-detach --repo "$repo" --root "$IMAGES_ROOT" --size "$SIZE"
fi
exec "$cli" gen --repo "$repo" --root "$IMAGES_ROOT" --size "$SIZE"
