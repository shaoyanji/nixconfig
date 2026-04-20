{
  pkgs,
  lib,
  ...
}: {
  # Desktop/user app layer built on top of minimal.
  imports = [
    ./minimal.nix
    ../shell
    # ../user/ai/opencode.nix # too bloated
  ];

  programs.nixvim.enable = true;
  home.packages = with pkgs;
    [
      # ── Moved from base (too heavy for servers) ──
      devenv # Developer environments (864 MB closure)
      nixd # Nix language server (588 MB closure, pulls llvm)
      ffmpeg # Audio/video processing (~1 GB closure)
      tesseract # OCR engine (~1 GB closure)
      graphviz # Graph visualization
      pi-coding-agent # AI coding agent (515 MB closure)
      python3 # Python interpreter
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
    ++ lib.optionals stdenv.isLinux [
      ani-cli
      audacity
      cmus # Terminal music player (~1 GB closure)
      lux # Video downloader (~1 GB closure)
      mpv
      # ytfzf
      gnuplot
      jp2a
      lm_sensors
      ethtool
      iotop
    ]
    ++ lib.optionals stdenv.hostPlatform.isx86_64 [
      skills
      keypunch
      qalculate-qt
      thunderbird-bin
      hyprpicker
      cliphist
      wl-clipboard
      simplex-chat-desktop
      qrrs
      cook-cli
      surge-cli
      supabase-cli
      turso-cli
      cloudflare-cli
      bootdev-cli
      wash-cli
      libation
    ]
    ++ lib.optionals stdenv.isDarwin [
      iina
      wget
      cocoapods
      m-cli
    ];

  home.sessionVariables = {
    EDITOR = lib.mkDefault "nvim";
  };
  programs.home-manager.enable = true;
}
