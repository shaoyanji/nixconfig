# Hybrid demo home-manager configuration — niri desktop without sops/secrets.
let
  userName = "user";
  userHome = "/home/user";
in
  {
    inputs,
    self,
    config,
    hostInventory,
    ...
  }: let
    # Same inventory-data role list as global.noDE — `hmModules` on the demo
    # host's entry, the original role as the no-field fallback.
    hostName = config.networking.hostName or "";
    # One predicate behind all three fields (lib/hm-shared.nix): the host's own
    # value when its inventory entry names it, the fallback when it does not.
    hostField = hmShared.forHost hostInventory hostName;
    hmModules = hostField "hmModules" ["roles.demo"];
    # Leaf lists for user.base/user.ai, resolved the same way as hmModules.
    hmBase = hostField "hmBase" (import self.modules."global.user").hmBaseFeatures;
    hmAi = hostField "hmAi" (import self.modules."global.user").hmAiFeatures;
    hmShared = import self.nixFiles.lib."hm-shared.nix" {inherit self inputs;};
  in {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "hm-backup";
      users.${userName} = {
        imports = hmShared.modulePaths hmModules;
        home.username = userName;
        home.homeDirectory = userHome;
        home.stateVersion = config.system.stateVersion;
      };
      sharedModules =
        [
          hmShared.hmUser
          hmShared.nixvim
          hmShared.nixIndex
        ]
        ++ hmShared.dankShell
        ++ [
          # Per-host ~/AGENTS.md from `.#homeAgents.<host>` (user "user").
          hmShared.homeAgents
        ];
      extraSpecialArgs = {
        inherit inputs self;
        hostName = config.networking.hostName;
        fleetHost = config.networking.hostName;
        hmBaseFeatures = hmBase;
        hmAiFeatures = hmAi;
      };
    };
  }
