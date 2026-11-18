# The R2 credential, read at run time — never at eval, so nothing lands in
# /nix/store. Sourced by `yt-store` and the listing the page's Cloud section reads;
# one copy for both, so the uploader and the lister cannot disagree about the
# bucket. The values are the three `scripts/task/nixcache.sh` exports.
#
# The sops file is the apikeys plane, which is a git submodule: a path in
# MEDIA_SOPS_FILE rather than a Nix path, so a host without the submodule checked
# out still evaluates. MEDIA_R2_* wins when set, which is how a test or CI hands
# the three values in with no age key.
export RCLONE_CONFIG_R2_TYPE=s3
export RCLONE_CONFIG_R2_PROVIDER=Cloudflare

if [ -z "${MEDIA_R2_ACCESS_KEY_ID:-}" ]; then
  sops_file="${MEDIA_SOPS_FILE:?MEDIA_SOPS_FILE is not set}"
  if ! json="$(sops -d --output-type json "$sops_file" 2>/dev/null)"; then
    echo "media-relay: cannot decrypt $sops_file with this user's age key" >&2
    exit 1
  fi
  MEDIA_R2_ACCESS_KEY_ID="$(jq -er '.["CLOUDFLARE"]["ACCESS"]["KEY"]["ID"]' <<<"$json")" || exit 1
  MEDIA_R2_SECRET_ACCESS_KEY="$(jq -er '.["CLOUDFLARE"]["SECRET"]["ACCESS"]["KEY"]' <<<"$json")" || exit 1
  MEDIA_R2_ENDPOINT="$(jq -er '.["CLOUDFLARE"]["S3"]["API"]["ENDPOINT"]' <<<"$json")" || exit 1
  unset json
fi

export RCLONE_CONFIG_R2_ACCESS_KEY_ID="$MEDIA_R2_ACCESS_KEY_ID"
export RCLONE_CONFIG_R2_SECRET_ACCESS_KEY="$MEDIA_R2_SECRET_ACCESS_KEY"
export RCLONE_CONFIG_R2_ENDPOINT="$MEDIA_R2_ENDPOINT"
