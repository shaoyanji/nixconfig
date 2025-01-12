{ pkgs, config, ... }:
let
  routerNAS = "/mnt/y/";
  sharedNAS = "/mnt/x/";
  wolfNAS = "/mnt/z/";
in
{
  home.file = {
    "nixconfig".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/projects/repo/nixconfig";
    "Documents/Obsidian-Git-Sync".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/documents/Obsidian-Git-Sync";
    "Documents/work".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/documents/work";
    "Documents/nixconfig".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/documents/nixconfig";
    "Documents/docs".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/documents";
    "Documents/books".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/books";
    "Downloads/downloads".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/downloads";
    "Applications".source = config.lib.file.mkOutOfStoreSymlink "${sharedNAS}/appimages";
    "Music/music".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/music";
    "Pictures/pictures".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/pics";
    "Videos/videos".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/video";
    "go/pkg".source = config.lib.file.mkOutOfStoreSymlink "${sharedNAS}/go/pkg";
    ".cargo/registry".source = config.lib.file.mkOutOfStoreSymlink "${sharedNAS}/.cargo/registry";
    ".ollama/models".source = config.lib.file.mkOutOfStoreSymlink "${sharedNAS}/ollama";
    # ".zen".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/zen";
    ".mozilla/firefox/profiles.ini".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/firefox";
    ".cloak/accounts.age".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/documents/secrets/cloak/accounts.age";
    ".cloak/key.txt".source = config.lib.file.mkOutOfStoreSymlink "${sharedNAS}/security/key.txt";
    # ".cloak/accounts".source = config.lib.file.mkOutOfStoreSymlink "${sharedNAS}/security/accounts";
  };
  xdg.configFile = {
    "btop".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/btop";
    "cmus".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/cmus";
    "ghostty".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/ghostty";
  };
}
