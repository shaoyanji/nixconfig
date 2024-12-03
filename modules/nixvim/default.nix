{config, pkgs, inputs, ...}:
{
  imports = [
    ./nixvim.nix

  ];
  home.packages = with pkgs; [
    markdownlint-cli
  ];
  home.sessionVariables ={
	  EDITOR = "nvim";
  };
}
