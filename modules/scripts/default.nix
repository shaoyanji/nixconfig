{ config, pkgs, ... }:

{
  home.packages = with pkgs;
  [
    (pkgs.writers.writePython3Bin "duckduck" {} /*python*/ ''
        print("hello world")
      '')
  ];
  home.file = {
  };
  
  home.sessionVariables = {
  };

}
