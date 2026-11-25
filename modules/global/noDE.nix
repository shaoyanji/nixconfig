# Container/no-DE home-manager configuration.
{
  inputs,
  self,
  config,
  user,
  hostInventory,
  ...
}: let
  hmShared = import self.nixFiles.lib."hm-shared.nix" {inherit self inputs;};
  # The container's own HM imports, declared next to its `features`/`modules`
  # in flake/host-inventory.nix — an edit to one container's user role lands on
  # that host only. `networking.hostName` resolves on every NixOS container;
  # the fallback keeps a host with no field on the original floor.
  hostName = config.networking.hostName or "";
  # One predicate behind both fields: the host's own value when its inventory
  # entry names it, the fallback when it does not.
  hostField = field: default:
    if builtins.isString hostName && builtins.hasAttr hostName hostInventory
    then hostInventory.${hostName}.${field} or default
    else default;
  hmModules = hostField "hmModules" ["roles.minimal" "shell"];
  # The per-host leaf list inside user.base: containers' hmModules name it
  # directly, and `hmBase` data rides extraSpecialArgs because `imports`
  # may not read `config`. user.ai is not imported on containers at all —
  # profiles.ai has no surface to disable.
  hmBase = hostField "hmBase" user.hmBaseFeatures;
in {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    users.${user.name} = {
      imports = map (m: self.modules.${m}) hmModules;
      home.username = user.name;
      home.homeDirectory = user.home;
    };
    sharedModules = [
      hmShared.hmUser
      hmShared.sops
      hmShared.nixvim
      hmShared.nixIndex
      # Per-host ~/AGENTS.md from `.#homeAgents.<host>`.
      hmShared.homeAgents
    ];
    extraSpecialArgs = {
      inherit inputs self;
      inherit (config.networking) hostName;
      fleetHost = config.networking.hostName;
      hmBaseFeatures = hmBase;
    };
  };
}
