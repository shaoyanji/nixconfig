{
  pkgs,
  lib,
  ...
}: {
  # Desktop/user app layer built on top of minimal.
  imports = [
    ./minimal.nix
    ../shell
    ../dev.nix
    ../user/ai/antigravity-cli.nix
  ];

  programs.nix-your-shell.enable = true;
  # programs.nixvim.enable = true; # disabled due to CI eval OOM
  home.packages = with pkgs;
    [
      # ── Moved from base (too heavy for servers) ──
      ffmpeg # Audio/video processing (~1 GB closure)
      graphviz # Graph visualization
      a2ps
      amfora
      astroterm
      caligula
      comodoro
      enscript
      gtree
      gucci
      jwt-cli
      minijinja
      multimarkdown
      ots
      starfetch
      termshark
      ticker
      todo-txt-cli
      ytcast
      zbar
      viu
      neocities
      mupdf
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      ani-cli
      cmus # Terminal music player (~1 GB closure)
      gnuplot
      jp2a
      lm_sensors
      ethtool
      iotop
    ]
    ++ lib.optionals stdenv.hostPlatform.isx86_64 [
      keypunch
      qalculate-qt
      hyprpicker
      cliphist
      wl-clipboard
      qrrs
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      iina
      wget
      cocoapods
      m-cli
    ];

  home.sessionPath = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    "/run/wrappers/bin"
  ];

  home.sessionVariables = {
    # EDITOR = lib.mkDefault "nvim";
  };
  programs.home-manager.enable = true;
}
