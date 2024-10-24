{ config, pkgs, inputs, ... }:
{
  imports = [ 
  ];
  
  programs.git = {
    enable=true;
    userName="shaoyanji";
    userEmail="jisifu@gmail.com";
    extraConfig = {
      pull.rebase=false;
    };
  };
  home.sessionVariables = {
  };
  home.packages = with pkgs; [
    #    sops #managed by sops module
    #   yq
    #    yq-go#managed by sops module
    #    pass
    #    gnupg
    #    age
  ];
  
  home.file={
    
  };

}
