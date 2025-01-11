{ config, pkgs, ... }:

{
  imports = [
        #    ./duckduck.nix
  ];
  home.packages = with pkgs;
  [
    (pkgs.writers.writeLuaBin "hellolua" {} /*lua*/ ''
        print("hello world")
   '')
    (pkgs.writers.writePython3Bin "hellopython" {} /*python*/ ''
        print("hello world")
   '')
  ];
  home.file = {
  };
  
  home.sessionVariables = {
  };

}
