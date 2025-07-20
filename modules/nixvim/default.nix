{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # ../kickstart.nixvim/nixvim.nix
    inputs.kickstart-nixvim.homeManagerModules.default
  ];
  programs.nixvim.enable = true;

  home.packages = with pkgs; [
    # inputs.kickstart-nixvim.homeManagerModules.default
    markdownlint-cli
  ];
  home.sessionVariables = {
    EDITOR = "nvim";
  };
}
