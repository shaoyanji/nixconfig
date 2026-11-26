#!/usr/bin/env bash
# appflow-send.sh — the send step the apps lane did not have.
#
# `agents:apps:draft` stops at the mailbox: sync.py writes into Drafts and its
# own header says nothing in it can send mail. A packet therefore waited for an
# operator click, which is the gap `apps-lane-has-no-send-task` recorded. This is
# that step, and the only verb in the lane that leaves the host.
#
# Three things must agree before a byte moves, and each is read, never assumed:
# the row sits at `prep`, the row's next action names the day the lane holds the
# send, and the packet directory still holds both PDFs. The hold is read back out
# of the record, so this fires on the day with nobody watching and refuses before
# it — EARLY=1 is the deliberate override.
#
#   appflow-send.sh -- <id> [--to ADDR] [--send]
#
# Dry unless --send (or CONFIRM=1): it prints the envelope, the account and the
# attachment sizes, which is what a review needs. A successful send writes the
# row itself, because a verb that transmits and leaves the ledger to memory is
# the same silent gap in a smaller place.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
db=$repo/scripts/task/apps-db.sh
config=${HIMALAYA_CONFIG:-$HOME/.config/himalaya/config.toml}
account=${APPFLOW_ACCOUNT:-bountystash}
sender=${APPFLOW_SENDER:-"Matt Ji <matt@bountystash.com>"}
store=${APPFLOW_SUBMISSIONS:-${XDG_STATE_HOME:-$HOME/.local/state}/appflow/submissions}

die() { printf 'appflow-send: %s\n' "$*" >&2; exit 1; }

# `-- <id>` is the documented form, but bash does not strip `--` for a script:
# it arrives as $1, so a parser that only rejects dashed arguments refuses the
# call the usage line itself teaches (measured 2026-11-26: every packet died on
# `usage`). Consume it here, and only here.
id=${1:-}
if [ "$id" = -- ]; then
  shift
  id=${1:-}
fi
if [ -z "$id" ] || [ "${id#--}" != "$id" ]; then
  die "usage: appflow-send.sh -- <id> [--to ADDR] [--send]"
fi
shift

to=''
send=0
while [ $# -gt 0 ]; do
  case $1 in
    --to) to=${2:?--to needs an address}; shift 2 ;;
    --send) send=1; shift ;;
    --dry) send=0; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ "${CONFIRM:-0}" = 1 ] && send=1

row=$(FORMAT=json "$db" get "$id" | jq -c '.record // .')
[ "$row" != "null" ] || die "no application $id in the archive"
field() { jq -r --arg k "$1" '.[$k] // "" | tostring' <<<"$row"; }

stage=$(field stage)
[ "$stage" = prep ] || die "$id sits at '$stage', not at prep — nothing staged to send"

next=$(field nextAction)
hold=$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' <<<"$next" | head -1 || true)
today=$(date +%F)
[ -n "$hold" ] || die "$id carries no send date: put one in the next action first"
if [ "$hold" \> "$today" ] && [ "${EARLY:-0}" != 1 ]; then
  die "held to $hold by the row's own next action (today $today); EARLY=1 overrides"
fi

dir=$(field folderPath)
dir=${dir:-$store/$id}
for f in anschreiben.pdf lebenslauf.pdf; do
  [ -s "$dir/$f" ] || die "packet incomplete: $dir/$f is missing or empty"
done
command -v pdftotext >/dev/null || die "pdftotext is needed to put the letter in the body"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
pdftotext "$dir/anschreiben.pdf" "$work/body.txt"
[ -s "$work/body.txt" ] || die "the letter PDF carries no text to put in the body"

[ -n "$to" ] || to=$(field recruiterEmail)
[ -n "$to" ] || to=$(grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' <<<"$next" | head -1 || true)
[ -n "$to" ] || die "$id names no recipient: pass --to, or put the address in the next action"

company=$(field company)
role=$(field role)
# The letter is the language evidence: a German body opens with Sehr geehrte,
# and the row's own language field has been wrong about a packet before.
if grep -qiE 'sehr geehrte|bewerbung' "$work/body.txt"; then
  language=de
else
  language=$(field language)
fi
case $language in
  de*|ger*) subject="Bewerbung – $role bei $company" ;;
  *) subject="Application – $role at $company" ;;
esac

python3 - "$dir" "$sender" "$to" "$subject" "$work/body.txt" >"$work/raw.eml" <<'PY'
import sys
from email.message import EmailMessage
from email.utils import formatdate, make_msgid

directory, sender, to, subject, body_path = sys.argv[1:6]
message = EmailMessage()
message["From"] = sender
message["To"] = to
message["Subject"] = subject
message["Date"] = formatdate(localtime=True)
message["Message-ID"] = make_msgid()
with open(body_path, encoding="utf-8") as handle:
    message.set_content(handle.read())
for name in ("anschreiben.pdf", "lebenslauf.pdf"):
    with open(f"{directory.rstrip('/')}/{name}", "rb") as handle:
        message.add_attachment(
            handle.read(), maintype="application", subtype="pdf", filename=name
        )
sys.stdout.write(message.as_string())
PY

printf 'to        %s\nsubject   %s\naccount   %s (%s)\npacket    %s\nattach    anschreiben.pdf %s B, lebenslauf.pdf %s B\nmessage   %s bytes\n' \
  "$to" "$subject" "$account" "$sender" "$dir" \
  "$(wc -c <"$dir/anschreiben.pdf" | tr -d ' ')" \
  "$(wc -c <"$dir/lebenslauf.pdf" | tr -d ' ')" \
  "$(wc -c <"$work/raw.eml" | tr -d ' ')"

if [ "$send" = 0 ]; then
  printf 'dry       nothing sent; re-run with --send to transmit\n'
  exit 0
fi

himalaya -a "$account" -c "$config" message send <"$work/raw.eml" ||
  die "himalaya refused the message; nothing left and nothing was recorded"

follow=$(python3 -c 'import datetime, sys; print((datetime.date.fromisoformat(sys.argv[1]) + datetime.timedelta(days=14)).isoformat())' "$today")
# The row was read at the top of this run and every gate above named it, so
# `prep` is the stage this write expects. Without the expectation the write
# guard refuses it *after* himalaya has already transmitted — the mail leaves
# and the ledger keeps saying prep, which is the resend this file exists to
# prevent.
if ! FORMAT=json "$db" update "$id" --expect-stage prep \
  --status "applied: sent $today to $to with anschreiben.pdf and lebenslauf.pdf" \
  --next-action "Follow up $follow if no reply; the mail left on $today" >/dev/null; then
  die "the mail left but the ledger write failed — set $id to applied by hand, now"
fi
printf 'sent      %s\nledger    applied, follow-up %s\n' "$to" "$follow"
