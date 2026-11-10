#!/usr/bin/env bash
# mail-alias.sh — create, list, expire and delete forwarding aliases on the
# ImprovMX domain, with a declared registry as the record of intent.
#
# WHY A SCRIPT AND NOT THE DASHBOARD: an alias is a disposable address whose
# whole value is that it can be revoked and that a leak says *which* service
# leaked. That only pays off if creating one is cheaper than handing out the
# real address, and deleting one is one command.
#
# TWO SOURCES, ON PURPOSE:
#   live      — api.improvmx.com, the truth about what forwards today
#   declared  — modules/config/mail-aliases.toml, the truth about intent
#               (kind, expiry, why it exists)
# `drift` compares them and exits 1. Nothing reconciles automatically: a
# rebuild must never need an API key, so creation and deletion stay explicit
# commands and the registry is the record they leave.
#
# THE TRAP THIS FILE EXISTS TO ABSORB: the API answers `404 {"message":"Not
# found."}` for a domain spelling it does not know, and says nothing about the
# spelling being the problem. `mail.shaoyanji.is-a-dev` (hyphen) 404s for GET,
# POST and DELETE alike, while `mail.shaoyanji.is-a.dev` (dot) answers 200 — the
# two differ by one character and both look right in a terminal. So every call
# resolves the domain against GET /v3/domains first: that collection call
# carries the account's real domain names and each one's aliases inline, and a
# name it does not contain is a loud error naming the ones it does.
#
#   reads  → that one collection call.
#   writes → POST/DELETE /domains/:domain/aliases, confirmed by re-reading the
#            list, because a status code cannot tell "landed" from "never
#            reached the route".
#
# Audit fields (id, created) come from the live list; kind, expires and note
# come from the registry — never the other way around.
#
# Exit: 0 ok · 1 drift / refused / expired · 2 cannot run (no key, no sops,
# API unreachable, registry will not parse).
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "${BASH_SOURCE[0]%/*}/lib/paths.sh"
secrets=$(apikeys_file)
reg="$repo/modules/config/mail-aliases.toml"

api_base="${MAIL_API_BASE:-https://api.improvmx.com}"
domain="${MAIL_DOMAIN:-mail.shaoyanji.is-a.dev}"
default_forward="${MAIL_FORWARD:-jisifu@gmail.com}"
patience="${MAIL_API_PATIENCE:-60}"
today="$(date +%F)"

HTTP=""
BODY_TEXT=""

die() {
  echo "mail-alias: $*" >&2
  exit 2
}

need() { command -v "$1" >/dev/null 2>&1 || die "$1 not on PATH"; }

load_key() {
  need sops
  [ -f "$secrets" ] || die "$secrets missing (modules/secrets submodule not checked out?)"
  MAIL_KEY="$(sops -d --extract '["IMPROVMX"]["API"]["KEY"]' "$secrets" 2>/dev/null)" ||
    die "IMPROVMX.API.KEY not in $secrets"
  [ -n "$MAIL_KEY" ] || die "IMPROVMX.API.KEY is empty"
}

# api METHOD PATH [BODY] — sets HTTP and BODY_TEXT. Retries a connection
# failure and a 5xx until `patience` seconds have passed; a 429 honours
# Retry-After. Any other status is returned as it came — including the 404 that
# means "wrong domain spelling", which must never be retried into silence.
api() {
  local method="$1" path="$2" body="${3:-}" start now waited=0 wait=4
  local -a args=(-s -m 25 -u "api:$MAIL_KEY" -X "$method" -o /tmp/mail-alias.body -w '%{http_code}')
  [ -n "$body" ] && args+=(-H 'Content-Type: application/json' -d "$body")
  start="$(date +%s)"
  while :; do
    HTTP="$(curl "${args[@]}" "$api_base$path" 2>/dev/null || echo 000)"
    BODY_TEXT="$(cat /tmp/mail-alias.body 2>/dev/null || true)"
    case "$HTTP" in
      429)
        wait="$(printf '%s' "$BODY_TEXT" | jq -r '.retry_after // empty' 2>/dev/null || true)"
        [[ "${wait:-}" =~ ^[0-9]+$ ]] || wait=10
        ;;
      000 | 500 | 502 | 503 | 504) wait=4 ;;
      *) return 0 ;;
    esac
    now="$(date +%s)"
    waited=$((now - start))
    [ "$waited" -lt "$patience" ] || return 0
    # Say so once, so a wait is not mistaken for a hang.
    [ "$waited" -lt 5 ] || [ "$waited" -gt 9 ] ||
      echo "mail-alias: ImprovMX answered $HTTP; retrying for up to ${patience}s" >&2
    sleep "$wait"
  done
}

# ---------------------------------------------------------------- registry ---

reg_json() {
  [ -f "$reg" ] || {
    echo '{"aliases":{}}'
    return 0
  }
  yq -p toml -o json "$reg" || die "registry $reg does not parse"
}

reg_names() { reg_json | jq -r '.aliases // {} | keys[]'; }

reg_get() { reg_json | jq -r --arg n "$1" --arg f "$2" '.aliases[$n][$f] // empty'; }

# reg_verify — a write that leaves an unparseable file is worse than a failed
# command, so every edit re-parses and restores the backup when it does not.
reg_verify() {
  if ! yq -p toml -o json "$reg" >/dev/null 2>&1; then
    mv "$reg.bak" "$reg"
    die "registry edit left $reg unparseable; restored the previous version"
  fi
  rm -f "$reg.bak"
}

reg_add() {
  local name="$1" forward="$2" kind="$3" expires="$4" note="$5"
  cp "$reg" "$reg.bak"
  {
    printf '\n[aliases."%s"]\n' "$name"
    [ -n "$kind" ] && printf 'kind = "%s"\n' "$kind"
    printf 'forward = "%s"\n' "$forward"
    [ -n "$expires" ] && printf 'expires = "%s"\n' "$expires"
    [ -n "$note" ] && printf 'note = "%s"\n' "$note"
    printf 'created = "%s"\n' "$today"
  } >>"$reg"
  reg_verify
}

reg_rm() {
  cp "$reg" "$reg.bak"
  awk -v name="$1" '
    $0 == "[aliases.\"" name "\"]" {skip = 1; next}
    skip && /^\[/ {skip = 0}
    !skip {print}
  ' "$reg.bak" >"$reg.dirty"
  # Leave exactly one trailing newline: the removed block takes the blank line
  # that separated it, and a file growing a blank tail every delete is noise in
  # the diff you are about to review.
  printf '%s\n' "$(cat "$reg.dirty")" >"$reg"
  rm -f "$reg.dirty"
  reg_verify
}

# ------------------------------------------------------------------ live -----

# live_aliases — one collection call, the domain's aliases inline. Sets LIVE
# to a JSON array [{alias, forward, id, created}]. Exits 2 when the call fails
# or when the configured domain is not one of the account's, because either
# way every later answer would be a guess.
live_aliases() {
  api GET /v3/domains
  if [ "$HTTP" != 200 ]; then
    die "cannot read /v3/domains (HTTP $HTTP): $BODY_TEXT"
  fi
  local found
  found="$(jq -r --arg d "$domain" '[(.domains // [])[] | select(.domain == $d)] | length' <<<"$BODY_TEXT")"
  if [ "$found" = 0 ]; then
    die "domain '$domain' is not in this account; it has: $(jq -r '[(.domains // [])[].domain] | join(", ")' <<<"$BODY_TEXT")"
  fi
  LIVE="$(jq -c --arg d "$domain" '
    (.domains // []) | map(select(.domain == $d)) | (.[0].aliases // [])
    | map({
        alias: .alias,
        forward: .forward,
        id: (.id // "" | tostring),
        created: ((.created // 0) / 1000 | floor | strftime("%Y-%m-%d"))
      })' <<<"$BODY_TEXT")"
}

live_has() { live_aliases; jq -e --arg n "$1" 'map(.alias) | index($n)' <<<"$LIVE" >/dev/null 2>&1; }

days_left() {
  local s e
  s="$(date -d "$today" +%s 2>/dev/null || echo 0)"
  e="$(date -d "$1" +%s 2>/dev/null || echo 0)"
  [ "$e" -gt 0 ] || return 0
  echo $(((e - s) / 86400))
}

is_expired() { [ -n "$1" ] && [[ "$1" < "$today" ]]; }

# ------------------------------------------------------------------ verbs ---

cmd_list() {
  local json=0
  [ "${1:-}" = "--json" ] && json=1
  load_key
  live_aliases
  if [ "$json" = 1 ]; then
    jq -c '.[] | {alias, forward, id, created}' <<<"$LIVE" |
      while IFS= read -r row; do
        name="$(jq -r .alias <<<"$row")"
        jq -c --arg k "$(reg_get "$name" kind)" --arg e "$(reg_get "$name" expires)" \
          --arg n "$(reg_get "$name" note)" '. + {kind: $k, expires: $e, note: $n}' <<<"$row"
      done
    return 0
  fi
  printf '%-22s %-26s %-11s %s\n' ALIAS FORWARD KIND EXPIRES
  local n=0 expired=0
  while IFS=$'\t' read -r name forward; do
    n=$((n + 1))
    local kind expires mark="-"
    kind="$(reg_get "$name" kind)"
    expires="$(reg_get "$name" expires)"
    if is_expired "$expires"; then
      mark="EXPIRED ($expires)"
      expired=$((expired + 1))
    elif [ -n "$expires" ]; then
      mark="$expires ($(days_left "$expires")d)"
    fi
    printf '%-22s %-26s %-11s %s\n' "$name" "${forward:--}" "${kind:--}" "$mark"
  done < <(jq -r '.[] | [.alias, .forward] | @tsv' <<<"$LIVE")
  printf '\nmail: %s live, %s declared, %s expired, %s free of 25\n' \
    "$n" "$(reg_names | wc -l | tr -d ' ')" "$expired" "$((25 - n))"
  [ "$expired" -eq 0 ] || echo "mail: run 'task mail:alias:prune' to drop the expired ones"
}

cmd_add() {
  local name="${1:-}" forward="$default_forward" kind="permanent" expires="" note=""
  shift || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --forward) forward="$2"; shift 2 ;;
      --kind) kind="$2"; shift 2 ;;
      --expires) expires="$2"; shift 2 ;;
      --note) note="$2"; shift 2 ;;
      *) die "unknown flag $1" ;;
    esac
  done
  [ -n "$name" ] || die "usage: add <alias> [--forward f] [--kind k] [--expires YYYY-MM-DD] [--note s]"
  load_key
  api POST "/v4/domains/$domain/aliases" \
    "$(jq -cn --arg a "$name" --arg f "$forward" '{alias: $a, forward: $f}')"
  local created=0
  case "$HTTP" in 200 | 201) created=1 ;; esac
  # A 404 here is the window, not a verdict: the list decides.
  live_has "$name" || created=0
  [ "$created" = 1 ] || die "create failed (HTTP $HTTP): ${BODY_TEXT:-no body}; $name is not live"
  reg_add "$name" "$forward" "$kind" "$expires" "$note"
  echo "$name@$domain -> $forward"
  [ -z "$expires" ] || echo "expires: $expires"
  echo "registry: $reg"
}

cmd_tmp() {
  local label="${1:-}" days="${MAIL_TMP_DAYS:-30}" forward="$default_forward"
  shift || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --days) days="$2"; shift 2 ;;
      --forward) forward="$2"; shift 2 ;;
      *) die "unknown flag $1" ;;
    esac
  done
  [ -n "$label" ] || die "usage: tmp <label> [--days N] — e.g. tmp notion"
  local slug expires name
  slug="$(printf '%s' "$label" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' |
    sed 's/-\+/-/g;s/^-//;s/-$//')"
  [ -n "$slug" ] || die "label '$label' has no usable characters"
  expires="$(date -d "+$days days" +%F)"
  name="$slug-$(od -An -tx1 -N4 /dev/urandom | tr -d ' \n')"
  cmd_add "$name" --forward "$forward" --kind temporary --expires "$expires" \
    --note "signup: $label"
  echo "revoke with: task mail:alias:rm NAME=$name"
}

cmd_rm() {
  local name="${1:-}" yes=0
  shift || true
  [ "${1:-}" = "--yes" ] && yes=1
  [ "${YES:-0}" = "1" ] && yes=1
  [ -n "$name" ] || die "usage: rm <alias> [--yes]"
  load_key
  if [ "$yes" != 1 ]; then
    printf 'delete %s@%s (and its registry entry)? [y/N] ' "$name" "$domain"
    local a=""
    read -r a </dev/tty || true
    [[ "$a" =~ ^[Yy]$ ]] || {
      echo "not deleted"
      exit 1
    }
  fi
  # Delete by numeric id, not by name: DELETE …/aliases/<name> answers 200 and
  # removes nothing (measured 2026-11-06 on v4), which is exactly the kind of
  # silent success that leaves an address forwarding after you revoked it.
  live_aliases
  local id
  id="$(jq -r --arg n "$name" 'map(select(.alias == $n))[0].id // empty' <<<"$LIVE")"
  if [ -z "$id" ]; then
    reg_rm "$name"
    echo "already gone upstream: $name@$domain (registry entry removed)"
    return 0
  fi
  api DELETE "/v4/domains/$domain/aliases/$id"
  # Prove it: a 404 means both "gone" and "no such route", so only the list
  # is evidence.
  if live_has "$name"; then
    die "delete reported HTTP $HTTP but $name is still live"
  fi
  reg_rm "$name"
  echo "deleted $name@$domain"
}

cmd_prune() {
  local yes=0
  [ "${1:-}" = "--yes" ] && yes=1
  [ "${YES:-0}" = "1" ] && yes=1
  load_key
  live_aliases
  local found=0 names
  names="$(reg_names)"
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    local exp
    exp="$(reg_get "$n" expires)"
    is_expired "$exp" || continue
    found=$((found + 1))
    if [ "$yes" = 1 ]; then
      YES=1 cmd_rm "$n" --yes || true
    else
      echo "expired: $n@$domain ($exp)"
    fi
  done <<<"$names"
  [ "$found" -gt 0 ] || {
    echo "mail: no expired aliases"
    return 0
  }
  [ "$yes" = 1 ] || {
    echo "mail: $found expired — rerun with YES=1 to delete"
    exit 1
  }
}

drift_lines() {
  local live declared
  live="$(jq -r '.[].alias' <<<"$LIVE" | sort)"
  declared="$(reg_names | sort)"
  comm -23 <(printf '%s\n' "$live") <(printf '%s\n' "$declared") |
    sed 's/^/live, undeclared: /'
  comm -13 <(printf '%s\n' "$live") <(printf '%s\n' "$declared") |
    sed 's/^/declared, not live: /'
}

cmd_drift() {
  load_key
  live_aliases
  local out
  out="$(drift_lines)"
  if [ -z "$out" ]; then
    echo "mail: registry and live agree ($(jq 'length' <<<"$LIVE") aliases)"
    return 0
  fi
  printf '%s\n' "$out"
  echo "mail: drift — declare what you created, delete what you retired"
  exit 1
}

# dns_check — the record truth, straight from DNS, so the verdict does not
# depend on the API's flapping domain route.
dns_check() {
  need dig
  local mx spf dmarc dkim ok=1
  mx="$(dig +short MX "$domain" @1.1.1.1 2>/dev/null | awk '{print $2}' | sort | tr '\n' ' ')"
  spf="$(dig +short TXT "$domain" @1.1.1.1 2>/dev/null | grep -c 'spf.improvmx.com' || true)"
  dmarc="$(dig +short TXT "_dmarc.$domain" @1.1.1.1 2>/dev/null | tr -d '"' || true)"
  dkim="$(dig +short TXT "dkimprovmx._domainkey.$domain" @1.1.1.1 2>/dev/null | tr -d '"' || true)"
  printf 'mx:    %s\n' "${mx:-MISSING}"
  printf 'spf:   %s\n' "$([ "${spf:-0}" -gt 0 ] && echo "ok (spf.improvmx.com)" || echo MISSING)"
  printf 'dmarc: %s\n' "${dmarc:-MISSING (expected v=DMARC1; p=reject;)}"
  printf 'dkim:  %s\n' "${dkim:-missing (optional on this plan; the API reports no expected value)}"
  [ -n "$mx" ] && [ "${spf:-0}" -gt 0 ] && [ -n "$dmarc" ] || ok=0
  [ "$ok" = 1 ]
}

cmd_verify() {
  load_key
  echo "api verdict:"
  api POST "/v4/domains/$domain/verify"
  if [ "$HTTP" = 200 ]; then
    jq -r '.records | "  mx=\(.mx.valid // false) spf=\(.spf.valid // false) dkim=\(.dkim1.valid // false) dmarc=\(.dmarc.valid // false)"' <<<"$BODY_TEXT"
  else
    echo "  unavailable right now (HTTP $HTTP) — DNS below is the ground truth"
  fi
  echo "dns:"
  dns_check || exit 1
}

cmd_doctor() {
  load_key
  api GET /v4/account
  local plan limit=""
  if [ "$HTTP" = 200 ]; then
    plan="$(jq -r '.account.plan.name // "?"' <<<"$BODY_TEXT")"
    limit="$(jq -r '.account.plan.aliases_limit // 0' <<<"$BODY_TEXT")"
  else
    plan="unreachable (HTTP $HTTP)"
  fi
  live_aliases
  echo "domain:   $domain"
  echo "plan:     $plan (${limit:-?} aliases)"
  echo "aliases:  $(jq 'length' <<<"$LIVE") live / $(reg_names | wc -l | tr -d ' ') declared"
  reg_json >/dev/null || die "registry does not parse"
  echo "registry: ok ($reg)"
  api POST "/v4/domains/$domain/verify"
  if [ "$HTTP" = 200 ]; then
    jq -r '.records | "api:      mx=\(.mx.valid // false) spf=\(.spf.valid // false) dkim=\(.dkim1.valid // false) dmarc=\(.dmarc.valid // false)"' <<<"$BODY_TEXT"
  else
    echo "api:      verify unavailable (HTTP $HTTP)"
  fi
  dns_check >/dev/null 2>&1 || true
  local drifted
  drifted="$(drift_lines)"
  if [ -z "$drifted" ]; then
    echo "drift:    none"
  else
    echo "drift:"
    printf '%s\n' "$drifted" | sed 's/^/  /'
  fi
}

case "${1:-}" in
  list | ls) shift; cmd_list "$@" ;;
  add) shift; cmd_add "$@" ;;
  tmp) shift; cmd_tmp "$@" ;;
  rm | delete) shift; cmd_rm "$@" ;;
  prune) shift; cmd_prune "$@" ;;
  drift) shift; cmd_drift "$@" ;;
  verify) shift; cmd_verify "$@" ;;
  doctor | check) shift; cmd_doctor "$@" ;;
  -h | --help | help)
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
