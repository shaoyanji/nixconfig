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
    # ../user/ai/opencode.nix # too bloated
    # ../user/ai/codex.nix
    ../user/ai/antigravity-cli.nix
  ];

  programs.nix-your-shell.enable = true;
  # programs.nixvim.enable = true; # disabled due to CI eval OOM
  home.packages = with pkgs;
    [
      # ── Moved from base (too heavy for servers) ──
      # peertube-viewer
      # pi-coding-agent # AI coding agent (515 MB closure)
      # devenv & nixd — tiered in dev.nix under profiles.dev.tier == "full"
      ffmpeg # Audio/video processing (~1 GB closure)
      # tesseract # OCR engine (~1 GB closure)
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
      # audacity
      cmus # Terminal music player (~1 GB closure)
      # mpv — declaratively managed with hardware tiers via programs.mpv in multimedia.nix
      # ytfzf
      gnuplot
      jp2a
      lm_sensors
      ethtool
      iotop
    ]
    ++ lib.optionals stdenv.hostPlatform.isx86_64 [
      # skills
      keypunch
      qalculate-qt
      # thunderbird-bin
      hyprpicker
      cliphist
      wl-clipboard
      # simplex-chat-desktop
      qrrs
      # Cloud CLIs (cook, surge, supabase, turso, cloudflare, bootdev, wash) — tiered in dev.nix
      # libation
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
