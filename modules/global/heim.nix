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
      inputs.zen-browser.packages.${pkgs.system}.default
      qutebrowser
      lan-mouse_git
      nix-top
  #failed to build
      # zed-editor-git
      # yt-dlp-git
      # libreoffice
      # hunspell
      # hunspellDicts.en_US
    ];
  };
}
