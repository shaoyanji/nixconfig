{ config, pkgs, inputs, ... }:
{
  imports = [ 
  ];
  
  programs.git = {
    enable=true;
    userName="Shao-yan (Matt) Ji";
    userEmail="100967396+shaoyanji@users.noreply.github.com";
    extraConfig = {
      pull.rebase=false;
    };
  };
  home.sessionVariables = {
  };
  home.packages = with pkgs; [
    lazygit
    gh
    #   sops #managed by sops module
    #   yq
    #   yq-go#managed by sops module
    #   pass
    #   gnupg
    #   age
  ];
  
  home.file={
    
  };
}
