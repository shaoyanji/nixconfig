# Anki sync server on delphi, offloaded from frieren 2026-11-02. Account and
# credential come from sops: the store holds a path, never a value.
# Why it moved, and how to read or rotate the credential: docs/service-offload.md.
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
