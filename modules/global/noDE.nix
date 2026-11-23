# Container/no-DE home-manager configuration.
{
  inputs,
  self,
  config,
  user,
  hostInventory,
  ...
}: let
  # The container's own HM imports, declared next to its `features`/`modules`
  # in flake/host-inventory.nix — an edit to one container's user role lands on
  # that host only. `networking.hostName` resolves on every NixOS container;
  # the fallback keeps a host with no field on the original floor.
  hostName = config.networking.hostName or "";
  hmModules =
    if builtins.isString hostName && builtins.hasAttr hostName hostInventory
    then hostInventory.${hostName}.hmModules or ["roles.minimal" "shell"]
    else ["roles.minimal" "shell"];
in {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    users.${user.name} = {
      imports = map (m: self.modules.${m}) hmModules;
      # Headless container hosts: skip the AI CLI stack (freebuff, qmd, agy,
      # aichat, ...) to keep closures small.
      profiles.ai.enable = false;
      home.username = user.name;
      home.homeDirectory = user.home;
    };
    sharedModules = [
      self.modules."global.hm-user"
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
