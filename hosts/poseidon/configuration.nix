{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    #    ./configuration2.nix
    ./hardware-configuration.nix
    ./nvidia.nix
    ../common/steam.nix
    ../common/base-desktop-environment.nix
    #../common/minimal-desktop.nix
    ../common/laptop.nix
    inputs.chaotic.nixosModules.default
    inputs.nix-index-database.nixosModules.nix-index
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
  programs.thunderbird.enable = true;
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
      speedtest-cli
      #dog
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
      ngrok #unfree
      asciinema
      navi

      surge #x86

      epr
      lynx
      translate-shell
      mc
      entr
      gitmoji-cli
      #gitmoji-changelog
      #sparkly-cli
      #lowcharts

      #hare
      #haredoc
      #go
      #cargo
      #tinygo
      wasmtime
      luajit
      alsa-utils
      sunshine
      moonlight-qt
    ];
    #variables = {
    # };
  };
  # services.transfer-sh = {
  #   enable = true;
  #   provider = "local";
  #   settings = {
  #     BASEDIR = "/var/lib/transfer.sh";
  #     LISTENER = ":8080";
  #     TLS_LISTENER_ONLY = false;
  #   };
  # };
  programs.virt-manager.enable = true;

  users.groups.libvirtd.members = ["devji"];

  virtualisation.libvirtd.enable = true;

  virtualisation.spiceUSBRedirection.enable = true;
  #android dev

  programs.adb.enable = true;
  users.users.devji.extraGroups = ["adbusers" "kvm" "libvirtd"];
  services.udev.packages = [
    pkgs.android-udev-rules
  ];
  #  dconf.settings = {
  #    "org/virt-manager/virt-manager/connections" = {
  #      autoconnect = ["qemu:///system"];
  #      uris = ["qemu:///system"];
  #    };
  #  };

  #  users.users.devji.extraGroups = ["libvirtd"];
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true; # enable copy and paste between host and guest

  #sunshine

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };
  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [47984 47989 47990 48010];
    allowedUDPPortRanges = [
      {
        from = 47998;
        to = 48000;
      }
      {
        from = 8000;
        to = 8010;
      }
    ];
  };
}
