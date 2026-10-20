# Hybrid demo home-manager configuration — niri desktop without sops/secrets.
let
  userName = "user";
  userHome = "/home/user";
in
  {
    inputs,
    self,
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
        home.stateVersion = config.system.stateVersion;
      };
      sharedModules = [
        inputs.kickstart-nixvim.homeManagerModules.default
        inputs.nix-index-database.homeModules.nix-index
        inputs.niri.homeModules.niri
        inputs.dms.homeModules.dank-material-shell
        inputs.dms.homeModules.niri
        # Per-host ~/AGENTS.md from `.#homeAgents.<host>` (user "user").
        ../user/ai/home-agents.nix
      ];
      extraSpecialArgs = {
        inherit inputs self;
        hostName = config.networking.hostName;
        fleetHost = config.networking.hostName;
      };
    };
  }
