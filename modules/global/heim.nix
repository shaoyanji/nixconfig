{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./home.nix
    #../dev.nix
    ../nixoshmsymlinks.nix
    ../shell/nushell.nix
  ];
  home = {
    username = "devji";
    homeDirectory = "/home/devji";
    packages = with pkgs; [
    ];
  };
}
