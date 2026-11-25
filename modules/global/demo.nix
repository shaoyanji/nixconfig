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
    # One predicate behind all three fields: the host's own value when its
    # inventory entry names it, the fallback when it does not.
    hostField = field: default:
      if builtins.isString hostName && builtins.hasAttr hostName hostInventory
      then hostInventory.${hostName}.${field} or default
      else default;
    hmModules = hostField "hmModules" ["roles.demo"];
    # Leaf lists for user.base/user.ai, resolved the same way as hmModules.
    hmBase = hostField "hmBase" (import self.modules."global.user").hmBaseFeatures;
    hmAi = hostField "hmAi" (import self.modules."global.user").hmAiFeatures;
  in {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "hm-backup";
      users.${userName} = {
        imports = map (m: self.modules.${m}) hmModules;
        home.username = userName;
        home.homeDirectory = userHome;
        home.stateVersion = config.system.stateVersion;
      };
      sharedModules = [
        self.modules."global.hm-user"
        inputs.kickstart-nixvim.homeManagerModules.default
        inputs.nix-index-database.homeModules.nix-index
        inputs.niri.homeModules.niri
        inputs.dms.homeModules.dank-material-shell
        inputs.dms.homeModules.niri
        # Per-host ~/AGENTS.md from `.#homeAgents.<host>` (user "user").
        self.modules."user.ai.home-agents"
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
