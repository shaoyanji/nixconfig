{
  pkgs,
  lib,
  ...
}: {
  # Desktop/user app layer built on top of minimal.
  imports = [
    ./minimal.nix
    ../shell
    ../wezterm
  ];

  home.packages = with pkgs;
    [
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
      mpv
      ytfzf
      gnuplot
      jp2a
      lm_sensors
      ethtool
      iotop
    ]
    ++ lib.optionals stdenv.hostPlatform.isx86_64 [
      qalculate-qt
      thunderbird-bin
      hyprpicker
      cliphist
      wl-clipboard
      simplex-chat-desktop
      # goose-cli
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

  programs.home-manager.enable = true;
}
