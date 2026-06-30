# Hybrid demo home-manager configuration — niri desktop without sops/secrets.
# User is "user", not "devji".
let
  userName = "user";
  userHome = "/home/user";
in {
  inputs,
  config,
  ...
}: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    users.${userName} = {
      imports = [
        ../roles/demo.nix
      ];
      home.username = userName;
      home.homeDirectory = userHome;
    };
    sharedModules = [
      inputs.kickstart-nixvim.homeManagerModules.default
      inputs.nix-index-database.homeModules.nix-index
      inputs.niri.homeModules.niri
      inputs.dms.homeModules.dank-material-shell
      inputs.dms.homeModules.niri
    ];
    extraSpecialArgs = {
      inherit inputs;
      hostName = config.networking.hostName;
    };
  };
}
