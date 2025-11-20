{
  inputs,
  pkgs,
  config,
  ...
}: {
  imports = [
    ../zen.nix
    ./home.nix
    #../dev.nix
    # ../shell/nushell.nix
  ];
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
