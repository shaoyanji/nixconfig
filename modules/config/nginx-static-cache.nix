# One nginx cache policy for compiled static trees.
# Both serve the same immutable store path, so the policy that describes it must
# only `Cache-Control` differed between the HTML and the content-hashed assets.
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
