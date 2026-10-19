# Container/no-DE home-manager configuration.
# Primary user constants: modules/global/user.nix
#
# NOTE: sharedModules intentionally do NOT import home-manager-shared.nix
# because container hosts should not pull in dms/niri desktop modules.
let
  user = import ./user.nix;
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
      users.${user.name} = {
        imports = [
          ../roles/minimal.nix
          ../shell
        ];
        # Headless container hosts: skip the AI CLI stack (crush, freebuff,
        # qmd, agy, aichat, ...) to keep closures small.
        profiles.ai.enable = false;
        home.username = user.name;
        home.homeDirectory = user.home;
      };
      sharedModules = [
        inputs.sops-nix.homeManagerModules.sops
        inputs.kickstart-nixvim.homeManagerModules.default
        inputs.nix-index-database.homeModules.nix-index
        # Per-host ~/AGENTS.md from `.#homeAgents.<host>`.
        ../user/ai/home-agents.nix
      ];
      extraSpecialArgs = {
        inherit inputs self;
        inherit (config.networking) hostName;
        fleetHost = config.networking.hostName;
      };
    };
  }
