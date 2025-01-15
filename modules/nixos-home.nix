{ pkgs,config, ... }:
let
    peachNAS = "/mnt/w/";
in
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
  home.sessionPath = [ "${peachNAS}/bin-x86" "${peachNAS}/go/bin-x86" ];
}
