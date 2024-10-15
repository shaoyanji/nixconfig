{config, pkgs, inputs, ...}:
{
  imports = [
    ./nixvim.nix

  ];
  home.sessionVariables ={
	  EDITOR = "nvim";
  };
}
