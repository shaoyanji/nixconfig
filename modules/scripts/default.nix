{ config, pkgs, ... }:

{
  imports = [
        #    ./duckduck.nix
  ];
  home.packages = with pkgs;[
    (pkgs.writers.writeBashBin "hellobash" {} /*bash*/ ''
        echo "hello world"
    '')
    (pkgs.writers.writeNimBin "hellonim" {} /*nim*/ ''
        echo "hello world"
    '')
    (pkgs.writers.writeNuBin "hellonu" {} /*nu*/ ''
        echo "hello world"
    '')
    (pkgs.writers.writeHaskellBin "hellohaskell" {} /*haskell*/ ''
        main = putStrLn "hello world"
    '')
    (pkgs.writers.writeJSBin "hellojavascript" {} /*javascript*/ ''
        console.log("hello world");
    '')
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
