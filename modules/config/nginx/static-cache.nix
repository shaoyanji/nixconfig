# One nginx cache policy for compiled static trees.
#
# The fleet docs site is served twice: over HTTP (`hosts/frieren/reverse-proxy.nix`)
# and over the UNIX-domain-socket bridge (`modules/services/uds-static-bridge.nix`).
# Both serve the same immutable store path, so the policy that describes it must
# exist once. Four copies of `open_file_cache …` used to live in those two files;
# only `Cache-Control` differed between the HTML and the content-hashed assets.
#
# Consume as:
#   extraConfig = staticCache.html;              # HTML + JSON
#   extraConfig = staticCache.hashed;            # *.css / *.js (hashed names)
#   extraConfig = staticCache.html + ''…'';      # append site-specific headers
{
  # Public for an hour, tolerated stale for a day: the bytes are a store path,
  # so a rebuild changes the path and a stale copy is never wrong for long.
  html = ''
    gzip_static on;
    open_file_cache max=1000 inactive=300s;
    open_file_cache_valid 3600s;
    open_file_cache_min_uses 1;
    open_file_cache_errors on;
    add_header Cache-Control "public, max-age=3600, stale-while-revalidate=86400" always;
  '';

  # Content-hashed names (style.<hash>.css): safe to freeze for a year.
  hashed = ''
    gzip_static on;
    open_file_cache max=1000 inactive=300s;
    open_file_cache_valid 3600s;
    add_header Cache-Control "public, max-age=31536000, immutable" always;
  '';
}
