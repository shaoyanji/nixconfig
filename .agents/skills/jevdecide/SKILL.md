---
name: jevdecide
description: "Jev-gated inbox cleaning: classify envelope metadata; delete only >=0.8; fetch bodies only when unsure."
---

# jevdecide — Jev-gated inbox cleaning

Jev (TypeSafe `jev-decide`) decides what to delete. The agent supplies **envelope
metadata first** and escalates to message bodies **only** for mail Jev is unsure about.

## Contract
- Metadata-only by default. Never fetch a body unless Jev returns a non-DELETE choice,
  a `DELETE` below the threshold, or a `REVIEW` label.
- Delete only when Jev says `DELETE` with `probability >= 0.8`.
- Bias to KEEP. Financial, security, legal, account, personal, and job/application mail
  is never deleted on metadata alone; when in doubt, keep.
- Trashing is recoverable (~30 days) but treat it as destructive.

## Canonical Jev tooling (do not reinvent)
- CLI: `jev-decide` (implemented in the `jev` skill at `scripts/jev.py`; provider
  `typesafe` or `openrouter`). `--min-probability 0.8` is the gate.
- Related skills: `jev`, `jev-triage` (generic record triage + review queues), and
  `email/email-inbox-triage` (prioritise/draft — NOT for deleting).

## Key setup (once per shell)
```sh
set -a; . "$HOME/.config/hermes/hermes.env"; set +a
export TYPESAFE_API_KEY="${TYPESAFE_API_KEY:-$TYPESAFEAI_API_KEY}"
```

## Criteria file (write once)
`/tmp/jev_inbox_criteria.json`:
```json
{
  "KEEP": "personal or human correspondence; security alerts and sign-in notices; financial statements, broker/order alerts, tax; legal or terms changes tied to a real account; receipts and shipping for goods actually ordered; job-application, recruiter, interview or ATS mail; government and admin notices; anything time-sensitive or requiring a reply",
  "DELETE": "marketing, promotional, newsletters, digests, retail sales, loyalty/hotel rewards, event or conference promo, webinar invites, job-board blasts and bulk match notifications, vendor product updates, social-media digests, breaking-news alerts",
  "REVIEW": "unclear from subject and sender alone"
}
```

## Step 1 — metadata only
```sh
himalaya envelope list -s <N> -w 200      # id, flags, subject, from, date, size
```
No bodies.

## Step 2 — classify each on subject + sender only
```sh
jev-decide classify --provider typesafe \
  --text "<subject> — from <sender>" \
  --criteria /tmp/jev_inbox_criteria.json \
  --min-probability 0.8 --review-label REVIEW
```
Read `.decisions.category.value` and `.decisions.category.probability`. One
`jev-decide` invocation per message; loop to batch.

## Step 3 — act
- `DELETE` with `probability >= 0.8` -> queue for Trash. **Do not fetch the body.**
- anything else -> fetch the body and re-classify with it appended:
  ```sh
  himalaya message read <id> --json \
    | jq -r '[.text_body[] as $i | .parts[$i].body.Text // .parts[$i].body.Html // ""] | join("\n")'
  ```
  Delete only if the body-inclusive call still returns `DELETE` with `probability >= 0.8`.

## Step 4 — trash
```sh
himalaya message move --to "[Gmail]/Trash" <id> <id> ...
```
Report the counts, the deleted list, and anything left as `REVIEW`.

## Bundled runner
`assets/jev_inbox.py` implements this end to end: report-only by default; `--limit N`
sets the window; `--apply` moves confirmed `DELETE>=0.8` ids to `[Gmail]/Trash`. A
`GUARD` list force-keeps obvious financial/security/application mail even if Jev says
DELETE. Run with:
```sh
nix-shell -p python3 --run "python3 ~/.agents/skills/jevdecide/assets/jev_inbox.py --limit 150"
```
