{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./nvidia.nix
    ../common/steam.nix
    ../common/base-desktop-environment.nix
    #../common/minimal-desktop.nix
    ../common/laptop.nix
    inputs.chaotic.nixosModules.default
  ];
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_cachyos;
  boot = {
    #extraModulePackages = with config.boot.kernelPackages; [v4l2loopback.out];
    #kernelModules = [
    #  "v4l2loopback"
    #];
    #extraModprobeConfig = ''
    #  options v4l2loopback exclusive_caps=1 card_label="Virtual Camera"
    #'';
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  networking.hostName = "poseidon"; # Define your hostname.
  environment = {
    systemPackages = with pkgs; [
      btrfs-progs
      (pkgs.wrapOBS {
        plugins = with pkgs.obs-studio-plugins; [
          wlrobs
          obs-backgroundremoval
          obs-pipewire-audio-capture
        ];
      })
      element-desktop
      audacity
      dust
      lz4
      rclone
      yank
      insect
      toot
      age
      pass
      cmus
      bitwarden-cli
      glow
      pop
      charm-freeze
      viu
      #wkhtmltopdf
      #ghostscript
      #        texlive.combined.scheme-full
      #pandoc
      #mods
      #aichat
      #tgpt
      #jekyll
      #bundler
      tldr
      scc
      diff-so-fancy
      entr
      exiftool
      fdupes
      most
      procs
      # rip
      rsync
      sd
      tre
      bandwhich
      glances
      gping
      dua-cli
      speedtest-cli
      dog
      buku
      ddgr
      khal
      mutt
      newsboat
      rclone
      taskwarrior3
      tuir
      httpie
      lazygit
      ngrok
      asciinema
      navi

      transfer
      surge #x86

      epr
      meetup-cli
      lynx
      hget
      translate-shell
      mc
      entr
      gitmoji-cli
      gitmoji-changelog
      sparkly-cli
      lowcharts

      #hare
      #haredoc
      #go
      #cargo
      #tinygo
      wasmtime
      luajit
      alsa-utils
    ];
    #variables = {
    # };
  };
  system.stateVersion = "24.11"; # Did you read the comment?
}
