# delphi — Oracle Cloud Infrastructure (OCI) Ampere A1 ARM64 headless server.
#
# Hardware:
#   Shape: VM.Standard.A1.Flex (Ampere Altra Neoverse N1, aarch64-linux)
#   Sizing: 4 OCPU, 24 GB RAM, 200 GB paravirtualized boot volume (OCI Always Free tier)
#
# Role:
#   Headless cloud server, remote offload worker, and Tailscale mesh peer.
#   Uses the globalModulesContainers (noDE) chain: minimal userland, sops
#   secrets, hardened SSH — no desktop bloat.
{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/profiles/base-node.nix
    ../../modules/profiles/server-hardening.nix
    ../../modules/profiles/firewall-baseline.nix
  ];

  networking.hostName = "delphi";

  # --- OCI Networking & Paravirtualized DHCP ---
  networking.useDHCP = lib.mkDefault true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ]; # SSH
    allowedUDPPorts = [ 41641 ]; # Tailscale direct WireGuard port
  };

  # Tailscale mesh networking & exit node capabilities
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
    extraSetFlags = [
      "--accept-routes=true"
      "--accept-dns=true"
    ];
  };

  # OCI Serial Console & Early Kernel Logging.
  # Allows debugging boots via OCI Cloud Shell / Console Connection.
  boot.kernelParams = [
    "console=ttyAMA0,115200"
    "console=tty0"
    "earlycon"
  ];

  # --- Headless Server Packages & Lightweight Base Closure ---
  # Keep the base closure small: btop and helix instead of baking a heavy
  # Neovim/Nixvim closure into every system generation.
  environment.systemPackages = with pkgs; [
    btop
    helix
    tmux
    git
    curl
    wget
    rsync
    jq
    ripgrep
    fd
  ];

  # Modal editor defaults (Catppuccin Mocha theme, relative line numbers).
  # This nixpkgs revision has no NixOS programs.helix module, so helix comes
  # from environment.systemPackages above and the config is deployed
  # system-wide via the XDG config search path (/etc/xdg).
  environment.variables.EDITOR = "hx";

  environment.etc."xdg/helix/config.toml".text = ''
    theme = "catppuccin_mocha"

    [editor]
    line-number = "relative"

    [editor.cursor-shape]
    insert = "bar"
    normal = "block"
    select = "underline"
  '';

  # Ephemeral / on-demand Neovim runner from kickstart.nixvim flake:
  # full IDE functionality on demand without permanently inflating the VM
  # closure (see PART V of the fleet closure policy).
  programs.bash.shellAliases = {
    nvim = "nix run github:shaoyanji/kickstart.nixvim --";
    vim = "helix";
  };

  system.stateVersion = "25.05";
}
