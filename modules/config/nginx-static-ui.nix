# The static-UI shape behind nginx: one immutable page derivation plus the
# two exact locations that serve it. `/` is answered by nginx's index module,
# which rewrites the request to `/index.html` and matches again — so that path
# needs its own exact location, or the rewrite lands on the vhost's
# `location /` and 404s. An alias to a file works only where the URI does not
# end in `/`. Used via `import`, same shape as nginx-static-cache.nix: sites
# add their own locations around the pair, they never rewrite it.
{
  # One immutable page: the UI is a store path, so a rebuild changes the path
  # and nothing is generated per request.
  package = pkgs: name: html:
    pkgs.runCommand "${name}-ui" {} ''
      mkdir -p $out
      install -m 0644 ${html} $out/index.html
    '';

  locations = page: {
    "= /" = {
      root = page;
    };
    "= /index.html" = {
      alias = "${page}/index.html";
    };
  };
}
