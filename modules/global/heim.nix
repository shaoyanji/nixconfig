{...}: {
  imports = [
    ./home.nix
    ../dev.nix
    ../nixoshmsymlinks.nix
  ];
  home = {
    username = "devji";
    homeDirectory = "/home/devji";
  };
}
