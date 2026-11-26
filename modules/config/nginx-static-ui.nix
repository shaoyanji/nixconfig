# A static UI's two exact locations: `/` is answered by nginx's index module,
# which rewrites the request to `/index.html` and matches again — so that path
# needs its own exact location, or the rewrite lands on the vhost's `location /`
# and 404s. An alias to a file works only where the URI does not end in `/`.
# Used via `import`, same shape as nginx-static-cache.nix: sites add their own
# locations around this pair, they never rewrite it.
page: {
  "= /" = {
    root = page;
  };
  "= /index.html" = {
    alias = "${page}/index.html";
  };
}
