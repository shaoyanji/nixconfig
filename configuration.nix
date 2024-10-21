{ pkgs, lib, config, inputs, ... }:
{
  #imports = [ inputs.sops-nix.nixosModules.sops];
  #sops = {
  #  defaultSopsFile = ./secrets.yaml;
  #  validateSopsFiles = false;
  #  age = {
  #    sshKeyPaths = ["/var/root/.ssh/id_ed25519"];
  #    keyFile = "/var/lib/sops-nix/keys.txt";
  #    generateKey = true;
  #  };
  #  secrets = {
  #    local ={};
  #  };
  #};
 # Nix configuration ------------------------------------------------------------------------------
  #
  nix.settings = {
    substituters= [
      "https://cache.nixos.org/"
    ];
    trusted-public-keys= [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
      trusted-users = [
        "@admin"
      ];
  };

  nix.configureBuildUsers = true;

  # Enable experimental nix command and flakes
  # nix.package = pkgs.nixUnstable;
  nix.extraOptions = ''
    auto-optimise-store = true
    experimental-features = nix-command flakes
  '' + lib.optionalString (pkgs.system == "aarch64-darwin") ''
    extra-platforms = x86_64-darwin aarch64-darwin
  '';

  # Create /etc/bashrc that loads the nix-darwin environment.
  programs.zsh.enable = true;

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  # Apps
  # `home-manager` currently has issues adding them to `~/Applications`
  # Issue: https://github.com/nix-community/home-manager/issues/1341
  environment.systemPackages = with pkgs; [
    kitty
    terminal-notifier
  ];

  # https://github.com/nix-community/home-manager/issues/423
  environment.variables = {
    #    TERMINFO_DIRS = "${pkgs.kitty.terminfo.outPath}/share/terminfo";
  };
  programs.nix-index.enable = true;

  # Fonts
  fonts.packages = [
    (pkgs.nerdfonts.override { fonts = ["JetBrainsMono"]; })
  ];
      
  system.defaults = {
    dock.autohide = true;
    finder.FXPreferredViewStyle = "clmv";
    loginwindow.GuestEnabled = false;
    NSGlobalDomain.AppleICUForce24HourTime = true;
    NSGlobalDomain.AppleInterfaceStyle = "Dark";
    NSGlobalDomain.KeyRepeat = 2;
  };

  # Keyboard
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToEscape = true;

  # Add ability to used TouchID for sudo authentication
  security.pam.enableSudoTouchIdAuth = true;
}
