{
  self,
  inputs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    self.modules."profiles.base-node"
    self.modules."profiles.nas-client"
    inputs.sops-nix.nixosModules.sops
    ./ai.nix
  ];

  # Tailscale for mesh networking
  services = {
    tailscale = {
      enable = true;
      useRoutingFeatures = "both";
    };
    resolved.enable = true;
    resolved.settings.Resolve.Domains = ["~.cloudforest-kardashev.ts.net" "~.fritz.box" "~."];
  };

  system.stateVersion = "25.05";
}
