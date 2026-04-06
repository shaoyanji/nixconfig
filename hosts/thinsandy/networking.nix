{
  config,
  pkgs,
  ...
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

  # --- Firewall ---
  networking.firewall.allowedTCPPorts = [
    8123  # HomeAssistant
    7351  # Stirling PDF
  ];
}
