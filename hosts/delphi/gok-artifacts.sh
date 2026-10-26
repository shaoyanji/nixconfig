#!/usr/bin/env bash
# gok-artifacts — receive the gokrazy appliance's build artifacts on delphi.
#
# The module substitutes the directory, the retention count and the tailscale
# path (pkgs.replaceVarsWith), and a 2-minute timer runs it. A file rather than a
# Nix string, because this deletes things: runs against a scratch directory are
# how the prune and the SHA256SUMS gate get exercised without a rebuild.
set -euo pipefail

# A systemd unit gets no login PATH, and on this host tar/zstd live in a user
# profile — so the tools are substituted as store paths by the module instead of
# being inherited from whoever happens to be logged in.
PATH=@path@
export PATH

dir=@directory@
keep=@keep@
incoming=$dir/incoming
mkdir -p "$incoming"

# Whatever Taildrop has queued for this host. Nothing queued is the normal case
# and is not an error, so the status is deliberately ignored: a tailscaled
# restart must not leave the timer unit failed forever.
@tailscale@ file get --conflict=overwrite "$incoming" || true

shopt -s nullglob
for f in "$incoming"/*.tar.zst; do
  name=$(basename "$f" .tar.zst)
  dest=$dir/$name
  if [ -d "$dest" ]; then
    # The same artifact twice (a retried run, a re-sent file): already unpacked.
    rm -f "$f"
    continue
  fi
  tmp=$dir/.unpack-$name
  rm -rf "$tmp"
  mkdir -p "$tmp"
  if ! tar --zstd -xf "$f" -C "$tmp" 2>/dev/null; then
    echo "gok-artifacts: $name does not extract; left in $incoming" >&2
    rm -rf "$tmp"
    continue
  fi
  # A truncated Taildrop transfer unpacks cleanly and would then serve corrupt
  # streams, so the build's own sums are the gate rather than the tar's exit code.
  if ! (cd "$tmp" && sha256sum -c --quiet SHA256SUMS >/dev/null 2>&1); then
    echo "gok-artifacts: $name fails its SHA256SUMS; discarding" >&2
    rm -rf "$tmp" "$f"
    continue
  fi
  mv "$tmp" "$dest"
  mv -f "$f" "$dir/$name.tar.zst"
  # `latest` is what the fetch URL names, so a deploy never guesses a build id.
  # -n because the previous target is itself a directory symlink.
  ln -sfn "$name" "$dir/latest"
  ln -sfn "$name.tar.zst" "$dir/latest.tar.zst"
  echo "gok-artifacts: received $name ($(du -h "$dir/$name.tar.zst" | cut -f1))"
done

# Keep the newest `keep` builds; each is ~140 MB and nothing else prunes them.
# Driven by the tarballs, not the directories: exactly one exists per completed
# build (so `incoming/` and a half-written `.unpack-*` can never be candidates),
# and pruning a directory off a list that also held `incoming/` cost a build the
# first time this ran — removing files from `incoming` makes it the newest entry.
mapfile -t old < <(
  ls -1t "$dir"/*.tar.zst 2>/dev/null |
    grep -v '/latest\.tar\.zst$' |
    sed 's/\.tar\.zst$//' |
    tail -n +$((keep + 1))
)
for stale in "${old[@]:-}"; do
  [ -n "$stale" ] || continue
  rm -rf "$stale" "$stale.tar.zst"
done
