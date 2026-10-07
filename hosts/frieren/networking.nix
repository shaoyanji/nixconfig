{ pkgs
, lib
, ...
}: {
  # --- Networking tools ---
  environment.systemPackages = with pkgs; [
    docker
    ethtool
    networkd-dispatcher
  ];

  # --- Docker ---
  virtualisation.docker = {
    enable = true;
    storageDriver = "btrfs";
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  # --- Stirling PDF (re-enabled 2026-09-29) ---
  # Port 7351 because the module default 8080 collides with pihole-web.
  # Opened here (not in configuration.nix's firewall block) so the
  # port lives next to the service that needs it.
  services.stirling-pdf = {
    enable = true;
    environment = {
      SERVER_PORT = "7351";
      SECURITY_ENABLELOGIN = "false";
    };
  };
  networking.firewall.allowedTCPPorts = lib.mkAfter [ 7351 ];
}
