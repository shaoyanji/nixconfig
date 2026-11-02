# The tooling side of the fleet's public cache. The Worker source is not rendered
# here: it is a project in the repo, deployed from this host with `task
# dev:nixcache:deploy`. docs/nix-cache-edge.md.
{pkgs, ...}: {
  # node runs the worker's tests directly (it strips types, so there is no build
  # step and no npm tree); wrangler bundles and deploys; rclone measures the R2
  # bucket against its budget.
  environment.systemPackages = with pkgs; [
    nodejs
    wrangler
    rclone
  ];
}
