{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.kickstart-nixvim.homeManagerModules.default
    ./home.nix
    #../dev.nix
    ../nixoshmsymlinks.nix
    # ../shell/nushell.nix
  ];
  programs.nixvim.enable = true;
  home = {
    username = "devji";
    homeDirectory = "/home/devji";
    packages = with pkgs;
      [
        markdownlint-cli
      ]
      ++ lib.optionals stdenv.isLinux [
      ]
      ++ lib.optionals stdenv.hostPlatform.isx86_64 [
      ]
      ++ lib.optionals stdenv.hostPlatform.isAarch64 [
      ];
  };

  # nixpkgs.config.allowUnfree = true;
}
