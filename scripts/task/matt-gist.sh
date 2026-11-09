#!/usr/bin/env bash
# scripts/task/matt-gist.sh — the resume is the fact, the page is the prose.
#
# The canonical copy is the one the application runner already uses:
# `~/.config/appflow/resume.json` (JSON Resume). The gist is the same document
# and is fetched when the base file is absent. Neither is read at build time —
# Nix builds must not touch $HOME or the network — so `sync` copies the resume
# into `lib/matt/resume.json` and everything else checks that copy.
#
#   matt-gist.sh pull        fetch the gists into the cache
#   matt-gist.sh sync        copy the projection of the canonical resume into the repo
#   matt-gist.sh sync-de     write the German corpus to $CONFIG/lebenslauf.json
#   matt-gist.sh drift       repo copy vs canonical, then role/project coverage (default)
#   matt-gist.sh push        what the gists would say; PUSH_APPLY=1 writes them
#
# Three gates, all about the same failure: a copy of a fact going stale.
#
# 1. Coverage. A role in the resume with no prose entry fails the site build; a
#    prose entry with no resume role is an orphan and shows up here. The site
#    closes the same loop at build time, so this is the readable half.
# 2. Parity. The German file is a translation, not a second source: its dates,
#    employers and language levels must be the English ones. `push` rewrites
#    those fields from the canonical file and refuses to write a gist where an
#    employer has no counterpart.
# 3. German coverage. The German corpus is `lib/matt/lebenslauf.json` — the prose
#    lives in the repo, not only in a gist, and every English role and project
#    must have a German counterpart. A German application must not receive
#    English headings over English bullets.
#
# `lib/matt/resume.json` is the projection, not the resume: the public repo gets
# no address, phone, e-mail, postal code or cloudinary asset. The page reads
# work, projects and languages only, and the packet build reads the canonical
# file in $HOME.
set -uo pipefail

repo=$(cd "$(dirname "$0")/../.." && pwd)
cache=${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig/matt-gist
base=${APPFLOW_RESUME:-$HOME/.config/appflow/resume.json}
base_de=${APPFLOW_LEBENSLAUF:-$HOME/.config/appflow/lebenslauf.json}
vendored=$repo/lib/matt/resume.json
# The German corpus is authored in the repo: there is no $HOME original for it,
# so the only copy that can go stale is a gist, and `push` writes that gist.
lebenslauf=$repo/lib/matt/lebenslauf.json
resume_gist=b7b844737e6469c9160bf41aa8970068
lebenslauf_gist=541b117a49173c4ba8c23b5d126b1fd1
cmd=${1:-drift}

pull() {
  mkdir -p "$cache"
  gh gist view "$resume_gist" --raw >"$cache/resume.json" || return 1
  gh gist view "$lebenslauf_gist" --raw >"$cache/lebenslauf.json" || return 1
  printf 'pulled resume.json and lebenslauf.json into %s\n' "$cache"
}

canonical() {
  if [ -s "$base" ]; then
    printf '%s\n' "$base"
  elif [ -s "$cache/resume.json" ]; then
    printf '%s\n' "$cache/resume.json"
  else
    return 1
  fi
}

canonical_de() {
  if [ -s "$base_de" ]; then
    printf '%s\n' "$base_de"
  elif [ -s "$cache/lebenslauf.json" ]; then
    printf '%s\n' "$cache/lebenslauf.json"
  else
    return 1
  fi
}

# The repo corpus is prose and must carry no contact block. The identity fields
# the public gist already publishes are merged back from it, so a German push
# cannot drop the address from a document that is meant to carry one.
merge_de() { # corpus gist out
  jq --slurpfile old <(jq -c '.' "$2") '
    ($old[0].basics // {}) as $b
    | .basics = ((.basics // {}) + {
        email: $b.email, phone: $b.phone, location: $b.location,
        profiles: $b.profiles, image: $b.image, signature: $b.signature
      } | with_entries(select(.value != null)))
  ' "$1" >"$3"
}

# What the public repo is allowed to hold. The page and the CV build read work,
# projects, education and languages; contact details stay in $HOME and are
# already published by the pages that are meant to publish them.
project_jq='
  del(.basics.email, .basics.phone, .basics.location, .basics.image, .basics.signature)
  | .basics |= (if . == null then null else . end)
'

sync() {
  src=$(canonical) || {
    echo "no resume: $base is absent and the cache is empty (run pull)" >&2
    return 1
  }
  jq -S "$project_jq" "$src" >"$vendored.tmp" || {
    echo "not JSON: $src" >&2
    rm -f "$vendored.tmp"
    return 1
  }
  mv "$vendored.tmp" "$vendored"
  printf 'synced %s -> lib/matt/resume.json (%s roles, %s projects, contact block stripped)\n' \
    "$src" "$(jq '.work | length' "$vendored")" "$(jq '.projects | length' "$vendored")"
}

# The application runner reads the German file from $CONFIG, the same directory as
# the English one. `push` writes the gist; this writes the local copy a German
# packet is actually built from, and takes the contact block the gist already
# publishes so a German CV is a resume rather than a list of employers.
sync_de() {
  [ -s "$lebenslauf" ] || {
    echo "no German corpus at $lebenslauf" >&2
    return 1
  }
  out=${APPFLOW_LEBENSLAUF:-$base_de}
  src=$(canonical_de) || src=""
  mkdir -p "$(dirname "$out")"
  if [ -n "$src" ]; then
    merge_de "$lebenslauf" "$src" "$out.tmp" || return 1
  else
    cp "$lebenslauf" "$out.tmp"
    echo "sync-de: no gist copy to take the contact block from (run pull)" >&2
  fi
  chmod 600 "$out.tmp"
  mv "$out.tmp" "$out"
  printf 'synced %s -> %s (%s roles, %s projects)\n' \
    "$lebenslauf" "$out" \
    "$(jq '.work | length' "$out")" "$(jq '.projects | length' "$out")"
}

drift() {
  src=$(canonical) || {
    echo "no resume to compare against (run pull)" >&2
    return 1
  }
  if diff -q <(jq -S "$project_jq" "$src") <(jq -S . "$vendored") >/dev/null; then
    echo "resume: vendored projection matches $src"
  else
    echo "resume: DRIFT between lib/matt/resume.json and the projection of $src"
    diff <(jq -S "$project_jq" "$src") <(jq -S . "$vendored") | head -40
  fi

  echo
  echo "coverage: resume roles against profile.json prose"

  joined=$(jq -rs '
    (.[0].work // []) as $r
    | (.[1].work // [] | map(select((.org // "") != "") | .org)) as $p
    | [ $r[].name ] as $names
    | {missing: ($names - $p), orphan: ($p - $names)}
  ' "$vendored" "$repo/lib/matt/profile.json")

  missing=$(printf '%s' "$joined" | jq -r '.missing[]')
  orphan=$(printf '%s' "$joined" | jq -r '.orphan[]')

  if [ -z "$missing" ]; then
    echo "  roles: every resume role has prose"
  else
    printf '  roles: MISSING prose for %s\n' "$(printf '%s' "$missing" | paste -sd, -)"
  fi
  if [ -z "$orphan" ]; then
    echo "  roles: no orphan prose"
  else
    printf '  roles: ORPHAN prose for %s\n' "$(printf '%s' "$orphan" | paste -sd, -)"
  fi

  echo
  echo "coverage: resume projects against projects.json entries"

  pj=$(jq -rs '
    (.[0].projects // []) as $r
    | (.[1].entries // [] | map(select((.resumeName // "") != "") | .resumeName)) as $p
    | [ $r[].name ] as $names
    | {missing: ($names - $p), orphan: ($p - $names)}
  ' "$vendored" "$repo/lib/matt/projects.json")

  pmissing=$(printf '%s' "$pj" | jq -r '.missing[]')
  porphan=$(printf '%s' "$pj" | jq -r '.orphan[]')

  if [ -z "$pmissing" ]; then
    echo "  projects: every resume project has an entry"
  else
    printf '  projects: MISSING entry for %s\n' "$(printf '%s' "$pmissing" | paste -sd, -)"
  fi
  if [ -z "$porphan" ]; then
    echo "  projects: no orphan entry"
  else
    printf '  projects: ORPHAN entry for %s\n' "$(printf '%s' "$porphan" | paste -sd, -)"
  fi

  echo
  echo "coverage: English roles and projects against the German corpus"

  if [ ! -s "$lebenslauf" ]; then
    echo "  lib/matt/lebenslauf.json is missing: a German application has no corpus"
    return 1
  fi

  dej=$(jq -rs '
    (.[0]) as $en
    | (.[1]) as $de
    | {
        roles: ([$en.work[].name] - [$de.work[].name]),
        projects: ([($en.projects // [])[].name] - [($de.projects // [])[] | .resumeName // empty]),
        invented: ([($de.projects // [])[] | .resumeName // empty] - [($en.projects // [])[].name]),
        silent: [($de.work // [])[] | select((.highlights // []) == []) | .name]
      }
  ' "$vendored" "$lebenslauf")

  dmissing=$(printf '%s' "$dej" | jq -r '.roles[]')
  dpmissing=$(printf '%s' "$dej" | jq -r ".projects[]")
  dinvented=$(printf '%s' "$dej" | jq -r '.invented[]')
  dsilent=$(printf '%s' "$dej" | jq -r '.silent[]')

  if [ -z "$dmissing" ]; then
    echo "  roles: every role has a German entry"
  else
    printf '  roles: MISSING German entry for %s\n' "$(printf '%s' "$dmissing" | paste -sd, -)"
  fi
  if [ -z "$dpmissing" ]; then
    echo "  projects: every project has a German entry"
  else
    printf '  projects: MISSING German entry for %s\n' "$(printf '%s' "$dpmissing" | paste -sd, -)"
  fi
  if [ -z "$dinvented" ]; then
    echo "  projects: no German entry claims a project the resume lacks"
  else
    printf '  projects: ORPHAN German entry for %s\n' "$(printf '%s' "$dinvented" | paste -sd, -)"
  fi
  if [ -z "$dsilent" ]; then
    echo "  roles: every German entry carries bullets"
  else
    printf '  roles: German entry has no bullets: %s\n' "$(printf '%s' "$dsilent" | paste -sd, -)"
  fi

  printf '\ncache: %s\n' "$cache"
  [ -n "$missing$orphan$pmissing$porphan$dmissing$dpmissing$dinvented$dsilent" ] && return 1
  return 0
}

# Rewrite the German copy's facts from the English one. Only fields JSON Resume
# fixes unambiguously: the employer name is the join key, and the fluency strings
# are a closed vocabulary rather than prose. Everything else — the translated
# bullets, the summary — is writing, and rewriting it here would be inventing it.
reconcile_de() {
  local en=$1 de=$2 out=$3
  jq --slurpfile en <(jq -c '.' "$en") '
    # The join keys are a closed vocabulary, not prose: the employer name is
    # spelled the same in both files, and the two language names differ only in
    # the language they are written in.
    def canon: ascii_downcase
      | if . == "englisch" then "english" elif . == "deutsch" then "german" else . end;
    def de_level:
      ascii_downcase as $f
      | if ($f | test("^(native|muttersprache)")) then "Muttersprache" else . end;

    ($en[0]) as $e
    |    ($e.work | map({key: .name, value: .}) | from_entries) as $byName
    | ($e.languages // []) as $langs
    | .work |= map(
        . as $w
        | ($byName[$w.name] // null) as $src
        | if $src == null then .
          else .startDate = $src.startDate | .endDate = ($src.endDate // "")
          end
      )
    | .languages |= [
        .[] as $l
        | ($langs[] | select((.language | canon) == ($l.language | canon)) | .fluency | de_level) as $level
        | {language: $l.language, fluency: $level}
      ]
  ' "$de" >"$out"
}

push() {
  src=$(canonical) || {
    echo "no resume to push (run pull)" >&2
    return 1
  }
  apply=${PUSH_APPLY:-0}
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT

  jq -S . "$src" >"$work/resume.json"
  cp "$work/resume.json" "$cache/resume.json"

  echo "resume.json    $(jq -r '.work | length' "$src") roles, $(jq -r '.projects | length' "$src") projects"
  echo "  gist https://gist.github.com/$resume_gist"

  # The German prose is the repo corpus. The gist is only asked for the identity
  # block the corpus deliberately does not hold.
  de=""
  if [ -s "$lebenslauf" ]; then
    de=$lebenslauf
  fi
  de_identity=$(canonical_de) || de_identity=""
  if [ -n "$de" ]; then
    if [ -n "$de_identity" ]; then
      merge_de "$de" "$de_identity" "$work/lebenslauf.stage.json" || {
        echo "lebenslauf.json: could not carry the contact block; the German copy is not written" >&2
        return 1
      }
    else
      cp "$de" "$work/lebenslauf.stage.json"
      echo "lebenslauf.json: no gist copy to take the contact block from (run pull)" >&2
    fi
    if ! reconcile_de "$src" "$work/lebenslauf.stage.json" "$work/lebenslauf.json"; then
      echo "lebenslauf.json: reconcile failed; the German copy is not written" >&2
      return 1
    fi
    missing=$(jq -r --slurpfile en <(jq -c '.' "$src") '
      .work as $de
      | [ $en[0].work[].name ] - [ $de[].name | select(. != null) ]
      | .[]
    ' "$work/lebenslauf.json" 2>/dev/null | paste -sd, -)
    if [ -n "$missing" ]; then
      echo "lebenslauf.json: REFUSED — no German entry for ${missing}" >&2
      echo "  the German corpus is a translation of the same employers; add them to lib/matt/lebenslauf.json first." >&2
      return 1
    fi
    # Compare against the staged merge, not the old gist: the contact block was
    # just carried over on purpose and is not a fact the English file rewrote.
    changed=$(jq -rn --slurpfile a <(jq -c '.' "$work/lebenslauf.stage.json") --slurpfile b <(jq -c '.' "$work/lebenslauf.json") \
      '[($b[0] | paths(scalars)) as $p | select(($a[0] | getpath($p)) != ($b[0] | getpath($p))) | ($p | map(tostring) | join("."))] | unique | .[]')
    if [ -n "$changed" ]; then
      echo "lebenslauf.json: facts rewritten from the English file:"
      while IFS= read -r field; do printf '  %s\n' "$field"; done <<<"$changed"
    else
      echo "lebenslauf.json: facts already match"
    fi
    cp "$work/lebenslauf.json" "$cache/lebenslauf.json"
  else
    echo "lebenslauf.json: no German corpus to check (lib/matt/lebenslauf.json is absent)"
  fi

  if [ "$apply" != 1 ]; then
    echo
    echo "dry run: PUSH_APPLY=1 gist file … writes these documents"
    return 0
  fi

  gh gist edit "$resume_gist" -f resume.json "$work/resume.json" || return 1
  echo "wrote   resume.json"
  if [ -n "$de" ]; then
    gh gist edit "$lebenslauf_gist" -f lebenslauf.json "$work/lebenslauf.json" || return 1
    echo "wrote   lebenslauf.json"
  fi
}

case "$cmd" in
  pull) pull ;;
  sync) sync ;;
  sync-de) sync_de ;;
  push) push ;;
  drift | "") drift ;;
  *)
    echo "usage: matt-gist.sh [pull|sync|drift|push]" >&2
    exit 2
    ;;
esac
