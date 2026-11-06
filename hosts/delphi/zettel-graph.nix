# The zettel reader on delphi: the private front end and an export of the
# private vault behind one tailnet mount. The service is loopback; the mount in
# configuration.nix is the only route in. docs/zettel-graph.md
{
  self,
  config,
  ...
}: {
  imports = [self.modules."services.zettel-graph"];

  services.zettelGraph = {
    enable = true;
    # Read from the registry, not typed again: the portal's `tailnetHost` is what
    # the mount cards link to, and a second copy is how the Origin check starts
    # refusing writes from the page that is actually open.
    tailnetHost = config.services.servicePortal.tailnetHost;
  };
}
