# The tooling side of the fleet's public cache. The Worker source is not rendered
# here: it is a project in the repo, deployed from this host with `task
# dev:nixcache:deploy`. docs/nix-cache-edge.md.
{
  config,
  pkgs,
  ...
}: let
  # The credentials this job needs — Cloudflare R2 keys and the cache signing key
  # — are decrypted with the *user's* age key, so the timer is a user unit. A root
  # unit would need a second sops plane for the same two secrets.
  repo = "${config.users.users.devji.home}/Documents/nixconfig";
  task = "${pkgs.go-task}/bin/task -t ${repo}/Taskfile.yml";
in {
  # node runs the worker's tests directly (it strips types, so there is no build
  # step and no npm tree); wrangler bundles and deploys; rclone measures the R2
  # bucket against its budget.
  environment.systemPackages = with pkgs; [
    nodejs
    wrangler
    rclone
  ];

  # The monthly handoff, and the reason it lives on delphi: this host already owns
  # the edge (deploy, key, budget) and its own gc, and it natively builds the
  # arch whose delta is smallest — aarch64, where the inputs the official caches
  # were built from are local. x86_64 is deliberately NOT in this list: there is
  # no /etc/nix/machines here, so `sync` would skip it anyway, and CI is the
  # builder that has a runner per arch. Collect first, because a refused push is
  # the budget gate doing its job and the collection is what makes room.
  systemd.user.services.nixcache-sync = {
    description = "Monthly: collect the edge cache, then build and push the aarch64 delta";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    # A build that also uploads needs more than the default 90 s stop timeout.
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = repo;
      TimeoutStartSec = "3h";
      ExecStart = "${pkgs.bash}/bin/bash -lc '${task} dev:nixcache:gc -- --delete && ${task} dev:nixcache:sync -- --hosts delphi,minyx'";
    };
  };

  # `monthly` is the first of the month; the random delay spreads it off the exact
  # hour when every other timer in the fleet fires.
  systemd.user.timers.nixcache-sync = {
    description = "Monthly edge-cache sync (delphi + minyx)";
    timerConfig = {
      OnCalendar = "monthly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    wantedBy = ["timers.target"];
  };
}
