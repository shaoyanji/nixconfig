{
  inputs,
  pkgs,
  config,
  ...
}: {
  imports = [
    ../zen.nix
    ./home.nix
    ../caelestia.nix
    #../dev.nix
    # ../shell/nushell.nix
  ];
  programs ={
    freetube = {
      enable = true;
      settings ={
  allowDashAv1Formats = true;
  checkForUpdates     = false;
  defaultQuality      = "1080";
  baseTheme           = "catppuccinMocha";
};
    };
  };
  services= {
    cliphist.enable = true;
    caffeine.enable=true;
    dropbox.enable=true;
    tailscale-systray.enable=true;

  };
  home = {
    username = "devji";
    homeDirectory = "/home/devji";
    packages = with pkgs;
      [
      ]
      ++ lib.optionals stdenv.isLinux [
      ]
      ++ lib.optionals stdenv.hostPlatform.isx86_64 [
      ]
      ++ lib.optionals stdenv.hostPlatform.isAarch64 [
      ];
  };
}
