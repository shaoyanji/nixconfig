{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
  ];
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup"; #for rebuild
    users.devji = {
      imports = [
        ./heim.nix
      ];
      home.packages = with pkgs; [
      ];
    };
    sharedModules = [
      # inputs.sops-nix.homeManagerModules.sops
    ];
    extraSpecialArgs = {inherit inputs;}; # Pass inputs to homeManagerConfiguration
  };
}
