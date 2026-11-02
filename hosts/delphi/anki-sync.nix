# Anki sync server on delphi — offloaded from frieren 2026-11-02.
#
# The cheapest win in the fleet, and the least obvious: an empty sync store
# (4 KB) held **430 MiB resident** on the NAS, because the service is a whole
# Anki build with an HTTP server attached. Its aarch64 closure is fully
# substitutable (6.4 MiB, no derivations to build), so this move costs one fetch.
#
# The account it shipped with was upstream's placeholder (`bob` / `password`),
# stored in plaintext in the Nix store where every local user can read it. Both
# halves are now real: `devji`, with a password from sops through the module's
# `passwordFile` path, passed to the unit as a systemd credential — the store
# carries a path, never a value. Read it, or rotate it, with
#
#   sops -d modules/secrets.yaml | yq -r '.anki-sync.password'
#
# The rename was free because `bob` had never synced: the per-user directory is
# keyed by username and was still empty. A rename after a real sync means moving
# `/var/lib/anki-sync-server/<user>` rather than editing this line.
{config, ...}: {
  sops.secrets."anki-sync/password" = {
    sopsFile = ../../modules/secrets.yaml;
    mode = "0400";
  };

  services.anki-sync-server = {
    enable = true;
    # `anki.frieren.lan` stays the name. frieren's nginx terminates it after its
    # own deploy; until then the transitional tunnel carries it. 27701 is opened
    # on `tailscale0` only, never on the public interface.
    address = "0.0.0.0";
    openFirewall = false;
    users = [
      {
        username = "devji";
        passwordFile = config.sops.secrets."anki-sync/password".path;
      }
    ];
  };
}
