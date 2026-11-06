# Container/no-DE home-manager configuration.
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
          self.modules."roles.minimal"
          self.modules."shell"
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
        self.modules."user.ai.home-agents"
      ];
      extraSpecialArgs = {
        inherit inputs self;
        inherit (config.networking) hostName;
        fleetHost = config.networking.hostName;
      };
    };
  }
