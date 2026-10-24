{
  lib,
  pkgs,
  config,
  osConfig ? {},
  fleetHost ? (osConfig.networking.hostName or (config.networking.hostName or "")),
  ...
}: let
  nixNAS = "/Volumes/data";
  hostName = fleetHost;
  invHost =
    if hostName != ""
    then (osConfig.fleet.inventory.hosts.${hostName} or (config.fleet.inventory.hosts.${hostName} or null))
    else null;
  # A cloud host has no NAS to link into, so it must not inherit /Volumes/data
  # symlinks that resolve to nothing. That is the declared category, not a name list.
  hasNas = (invHost.category or "") != "cloud";
  cfg = config.nixoshmsymlinks;
in {
  options.nixoshmsymlinks = {
    enable =
      lib.mkEnableOption "NAS-backed home directory symlinks"
      // {
        default = hasNas;
      };
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = [];
      file = {
        # "nixconfig".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/projects/repo/nixconfig";
        "vaults/personal".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/Obsidian-Git-Sync";
        "vaults/work".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/work";
        "Documents/nixconfig".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/nixconfig";
        "Documents/jobby".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/jobby";
        "Documents/docs".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/documents";
        "Documents/books".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/books";
        "Downloads/downloads".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/downloads";
        "Downloads/storage".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/storage";
        "Applications/appimages".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/appimages";
        "Music/muzik".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/music";
        "Pictures/pictures".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/pics";
        "Videos/videos".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/video";
        "Libation/Books".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/audiobooks/Books";
        # "go/pkg".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/cache/go/pkg";
        # ".cargo/registry".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/cache/.cargo/registry";
        ".ollama/models".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/ollama";
        # ".zen".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/zen";
        # ".mozilla/firefox/profiles.ini".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/firefox";
        # ".cloak/accounts.age".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/security/accounts.age";
        # ".cloak/key.txt".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/security/key.txt";
        # "gokrazy/hello".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/hello";
        # ".simplex".source = config.lib.file.mkOutOfStoreSymlink "${nixNAS}/.simplex";
      };
      sessionPath =
        lib.optionals pkgs.stdenv.hostPlatform.isAarch64 [
          # "${nixNAS}/bin-aarch64"
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
          # "${nixNAS}/bin-x86"
        ];
      sessionVariables = {};
    };
  };
}
