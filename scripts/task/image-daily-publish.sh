#!/usr/bin/env bash
# image-daily-publish.sh — upload kept assets to Cloudinary, write the manifest, deploy the frontend
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=image-daily-engine.sh
source "$here/image-daily-engine.sh"


# A publish that rebuilds the manifest smaller than what is being served means the
# tree on this host is a slice of the bank: 2026-11-21 on delphi, 556 assets became
# 144 with every upload still intact and the gallery lost the rest. Restore the
# served manifest and stop. `served` and `urls_backup` are locals of cmd_publish.

publish_shrink_guard() {
  [ -n "${urls_backup:-}" ] || return 0
  # The count comes from the backup rows, not from `cmd_publish`'s variable: bash
  # scopes by call dynamic, so an assignment further down the publish path clobbered
  # it and the guard compared against nothing (2026-11-22: "651 asset(s) but  are
  # being served", then `[: : integer expected`, and the deploy was refused).
  local now served
  now=$(jq -r '.count // 0' "$IMAGES_ROOT/published/manifest.json" 2>/dev/null || echo 0)
  served=$(grep -c . "$urls_backup" 2>/dev/null || true)
  [ "${now:-0}" -ge "${served:-0}" ] && return 0
  cp -f "$urls_backup" "$IMAGES_ROOT/published/urls.tsv"
  build_index
  rm -f "$urls_backup"
  die "publish refused: this host sees $now asset(s) but $served are being served — publish where IMAGES_ROOT holds the whole bank (frieren: /Volumes/data/pics/generated), or FORCE=1 to shrink on purpose"
}


# A manifest is a union, not a snapshot. Publishing from a host that holds a slice
# of the bank rewrote the served gallery down to that slice — 2026-11-21 on delphi,
# 597 assets became 144 with every upload intact — and refusing the shrink only
# turned that into a blocked publish. The served manifest is the prior: a row that
# is already being served names an asset, and `path` is what makes two rows one.
#
# The rows on this host win, so a re-upload's URL replaces the old one; a path only
# the served manifest knows is carried forward untouched. An unreachable manifest
# leaves the local rows to publish alone, and `publish_shrink_guard` then decides.
# FORCE=1 skips the merge, because a deliberate purge is the one publish that means
# to drop assets.

merge_served_urls() {
  local rows=$IMAGES_ROOT/published/urls.tsv tmp=$IMAGES_ROOT/published/.served.$$
  local from=${MERGE_FROM:-https://${PROJECT:-bountystash-assets}.pages.dev/manifest.json}
  if [ "${FORCE:-0}" = "1" ]; then
    say "merge: FORCE=1, publishing this host's rows only"
    return 0
  fi
  if [ "${MERGE:-1}" != "1" ]; then
    say "merge: MERGE=0, publishing this host's rows only"
    return 0
  fi
  [ -s "$rows" ] || return 0
  if ! curl -fsS --max-time 25 "$from" -o "$tmp.json" 2>/dev/null; then
    say "merge: $from answered nothing — publishing this host's rows only"
    rm -f "$tmp.json"
    return 0
  fi
  if ! jq -r '.assets[]? | [.path, .url, ((.bytes // 0) | tostring)] | @tsv' "$tmp.json" >"$tmp.remote" 2>/dev/null; then
    say "merge: $from is not a manifest — publishing this host's rows only"
    rm -f "$tmp.json" "$tmp.remote"
    return 0
  fi
  cut -f1 "$rows" >"$tmp.have"
  awk -F'\t' -v have="$tmp.have" '
    BEGIN { while ((getline l < have) > 0) seen[l] = 1 }
    NF >= 2 && !($1 in seen) { print }
  ' "$tmp.remote" >"$tmp.added"
  local local_n remote_n total
  local_n=$(grep -c . "$tmp.have" || true)
  remote_n=$(grep -c . "$tmp.added" || true)
  if [ "${remote_n:-0}" -gt 0 ]; then
    cat "$rows" "$tmp.added" | sort -t"$(printf '\t')" -k1,1 >"$tmp.merged" && mv -f "$tmp.merged" "$rows"
  fi
  total=$(grep -c . "$rows" || true)
  say "merge: ${local_n:-0} local + ${remote_n:-0} from the served manifest = ${total:-0} asset(s)"
  rm -f "$tmp.json" "$tmp.remote" "$tmp.have" "$tmp.added"
}


cmd_publish() {
  need jq
  local lane PUBLISH_SHIFTED=0 PUBLISH_GONE=0
  # The publish gate runs first: a manifest rewrite from a family that lost a
  # file or a breaker is the mistake it exists to catch (43 generations, 0
  # keeps, 2026-11-22–23). GATE=0 skips it for a deliberate one-off repair.
  if [ "${GATE:-1}" = "1" ]; then
    bash "$here/image-daily-gate.sh" || die "publish gate failed — refusing to ship (GATE=0 overrides)"
  fi
  # A publish with no local tree is still a publish: the rows are the manifest and
  # the account completes them. Only an empty manifest beside no ledger is a
  # publish with nothing to say.
  if [ ! -d "$IMAGES_ROOT/src" ] && [ ! -s "$IMAGES_ROOT/published/urls.tsv" ]; then
    die "nothing to publish: no $IMAGES_ROOT/src and no rows in $IMAGES_ROOT/published/urls.tsv"
  fi
  # A publish on a host that does not hold the bank rewrites the manifest down to
  # the batch it can see: 2026-11-21 on delphi, 556 assets became 144 with every
  # upload still intact. Remember what was being served before staging, and refuse
  # to shrink it without FORCE=1.
  local served=0 urls_backup=
  if [ -f "$IMAGES_ROOT/published/manifest.json" ]; then
    served=$(jq -r '.count // 0' "$IMAGES_ROOT/published/manifest.json" 2>/dev/null || echo 0)
  fi
  if [ -s "$IMAGES_ROOT/published/urls.tsv" ] && [ "${FORCE:-0}" != "1" ]; then
    urls_backup=$IMAGES_ROOT/published/.urls.served.$$
    cp -f "$IMAGES_ROOT/published/urls.tsv" "$urls_backup"
  fi
  for lane in site wall blog badge; do
    [ "$(lane_setting "$lane" publish)" = "true" ] || continue
    stage_publish
  done
  if [ "$PUBLISH_SHIFTED" -gt 0 ] || [ "$PUBLISH_GONE" -gt 0 ]; then
    say "publish: $PUBLISH_SHIFTED keep row(s) already served under another day, $PUBLISH_GONE with no file left"
  fi
  # The manifest this host builds is the update; the one being served is the prior,
  # and the account is the authority both are checked against.
  merge_served_urls
  adopt_cloudinary
  build_index
  say "$(find "$IMAGES_ROOT/published" \( -name '*.png' -o -name '*.jpg' \) | wc -l) asset(s) staged"
  publish_shrink_guard
  if [ "${DRY:-0}" = "1" ]; then
    say "dry run: not uploading"
    return 0
  fi
  # Cloudinary is the asset plane, not a deployed gallery: the delivery URL
  # carries its own resize (`f_auto,q_auto,w_1200`), so a consumer picks the
  # size it needs from one upload and this tree never becomes a website. The
  # urls.tsv beside the assets is the manifest a consumer reads.
  local rel url id rows=$IMAGES_ROOT/published/urls.tsv restaged=$IMAGES_ROOT/published/.restaged.$$
  local fresh=$IMAGES_ROOT/published/.urls.$$
  # A public id is derived from the path and a kept plate is never re-rendered, so
  # a path the manifest already carries is already served. Uploading it again is
  # the difference between a thirty-second round publish and a ten-minute one, and
  # nobody is watching either way. REUPLOAD=1 puts every staged file back over the
  # wire, which is what a forced re-render of an existing slug needs.
  local known=$IMAGES_ROOT/published/.known.$$
  : >"$known"
  if [ "${REUPLOAD:-0}" != "1" ] && [ -s "$rows" ]; then
    cut -f1 "$rows" >"$known"
  fi
  # A publish replaces only the rows it restaged. Truncating the manifest deletes
  # every asset whose file is not on this host, so a publish from a machine that
  # does not hold the bank rewrites the frontend down to that one batch.
  find "$IMAGES_ROOT/published" \( -name '*.png' -o -name '*.jpg' \) | sort >"$restaged"
  : >"$fresh"
  while IFS= read -r file; do
    rel=${file#"$IMAGES_ROOT/published/"}
    # A badge is addressed by host, not by day: the site map names
    # `assets/fleet/<host>`, so a re-render replaces the mark in place and
    # `lib/site/host-badges.json` never has to learn a new date.
    id="assets/${rel%.*}"
    case $rel in badge/*) id="assets/fleet/$(basename "${rel%.*}")" ;; esac
    # Copy the existing row forward instead of skipping the file silently: the
    # merge below would otherwise read the file as restaged-but-unwritten and
    # delete an asset that is still being served.
    if [ -s "$known" ] && grep -qxF -- "$rel" "$known"; then
      awk -F'\t' -v r="$rel" '$1 == r' "$rows" >>"$fresh"
      continue
    fi
    url=$(bash "$repo/scripts/task/cloudinary.sh" upload "$file" --public-id "$id") || {
      say "publish: upload failed for $rel"
      rm -f "$fresh" "$restaged" "$known"
      return 1
    }
    printf '%s\t%s\t%s\n' "$rel" "$url" "$(stat -c%s "$file")" >>"$fresh"
    say "uploaded $rel"
  done <"$restaged"
  if [ -s "$rows" ]; then
    awk -F'\t' -v list="$restaged" '
      BEGIN { while ((getline l < list) > 0) { sub(/^.*\/published\//, "", l); seen[l] = 1 } }
      !($1 in seen)
    ' "$rows" >>"$fresh"
  fi
  mv -f "$fresh" "$rows"
  rm -f "$restaged" "$known"
  say "$(wc -l <"$IMAGES_ROOT/published/urls.tsv") asset(s) on Cloudinary"
  build_index
  publish_shrink_guard
  deploy_frontend
}

cmd_publish "$@"
