{ pkgs, ... }:

{
  imports = [ 
    ./home.nix
    ../dev.nix
  ];
  home = {
    username = "devji";
    homeDirectory= "/home/devji";
    stateVersion = "24.11"; # Please read the comment before changing.
    packages = with pkgs; [
   ];

    file = {
    };

    sessionVariables = {
    };
  };
 
  nixpkgs.config.allowUnfree = true;
  # nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #   "obsidian"
  # ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
