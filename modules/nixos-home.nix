{ pkgs,config, ... }:
{
  imports = [ 
    ./global/heim.nix
    ./hyprland.nix
    ./hypr
    ./nixoshmsymlinks.nix
  ];
  home.packages = with pkgs; [
  ];
  home.file = {
  };
   home.sessionVariables = {
    #    PATH = "/nix/var/nix/profiles/default/bin:$HOME/.local/.bin/:$PATH";
   };
}
