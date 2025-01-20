{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./home.nix
    ../dev.nix
    ../nixoshmsymlinks.nix
  ];
  home = {
    username = "devji";
    homeDirectory = "/home/devji";
    packages = with pkgs; [
      inputs.zen-browser.packages.${pkgs.system}.default
      qutebrowser
      libreoffice
      hunspell
      hunspellDicts.en_US
    ];
  };
}
