{
  pkgs,
  ...
}: {
  imports = [
    ./base-node.nix
    ./nas-client.nix
  ];

  services = {
    keybase.enable = true;
    kbfs.enable = true;
    xserver.xkb = {
      layout = "us";
      variant = "";
    };
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
      publish = {
        enable = true;
        userServices = true;
      };
    };
    printing = {
      enable = true;
      listenAddresses = ["*:631"];
      allowFrom = ["all"];
      browsing = true;
      defaultShared = true;
      openFirewall = true;
      drivers = [
        pkgs.hplip
        pkgs.hplipWithPlugin
      ];
    };
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    pulseaudio.enable = false;
    tailscale.enable = true;
    tailscale.useRoutingFeatures = "both";
    resolved.enable = true;
    resolved.settings.Resolve.Domains = ["~.cloudforest-kardashev.ts.net" "~.fritz.box" "~."];
  };

  programs.nix-ld.enable = true;

  security.rtkit.enable = true;

  hardware.bluetooth.enable = true;

  users.users.devji.extraGroups = ["docker" "incus-admin" "video"];
}
