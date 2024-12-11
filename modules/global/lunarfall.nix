{ pkgs,config, ... }:

{
  imports = [ 
    ./heim.nix
    ../nixoshmsymlinks.nix
  ];
  
  nixpkgs.config.allowUnfree = true;

  #nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #           "obsidian"
  #         ];

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
  ];
 # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
  };

   home.sessionVariables = {
      XDG_DATA_DIRS="$XDG_DATA_DIRS:$HOME/.nix-profile/share:/nix/var/nix/profiles/default/share";
      PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH:$HOME/go/bin:$HOME/.cargo/bin:$HOME/go/bin-aarch64";
   };
   programs.home-manager.enable = true;
}
