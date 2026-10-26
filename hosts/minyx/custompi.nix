# minyx — Raspberry Pi 3 Model B, retooled as the fleet's tunnel/jump box.
#
# 1 GiB of RAM on a USB stick with a known under-voltage history: every setting
# here is about RAM, store size and keeping the medium alive.
{
  config,
  pkgs,
  ...
}: let
  user = import ../../modules/global/user.nix;
in {
  imports = [../../modules/config/authorized-keys.nix];

  # The old config reserved 256M of this box's 1 GiB for a VideoCore that a
  # headless jump host never shows anything on.
  boot.kernelParams = ["cma=16M"];
  boot.tmp.cleanOnBoot = true;

  # aarch64 closures are built on delphi and substituted here. Four Cortex-A53s
  # OOM before finishing one compile, so this is the setting that stops the Pi
  # from trying — not a tuning knob.
  nix.settings = {
    max-jobs = 1;
    cores = 1;
    auto-optimise-store = true;
  };

  # No swap file on the stick: compressed RAM only.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # The store is the only thing that grows between fleet updates, so bound it.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  networking = {
    hostName = "minyx";
    useDHCP = true;
    # Only sshd listens. Tailscale is outbound-initiated and installs its own
    # rules, so it needs no inbound hole here.
    firewall.allowedTCPPorts = [22];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  services.tailscale.enable = true;

  # This box had no system account at all: the old chain created only a
  # home-manager user entry, so there was nothing to log in as once HM went away.
  users.users.${user.name} = {
    isNormalUser = true;
    home = user.home;
    description = user.shortName;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = config.ssh.authorizedKeys.keys;
  };

  environment.systemPackages = with pkgs; [
    age
    curl
    gh
    git
    jq
    mosh
    rsync
    tmux
  ];

  documentation.nixos.enable = false;
}
