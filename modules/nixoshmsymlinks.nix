{ pkgs,config, ... }:
let
  routerNAS = "/mnt/y/";
  sharedNAS = "/mnt/x/";
  wolfNAS = "/mnt/z/";
in
{
  home.file = {
    "Documents/Obsidian-Git-Sync".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/documents/Obsidian-Git-Sync";
    "Documents/work".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/documents/work";
    "Documents/nixconfig".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/documents/nixconfig";
    "Documents/books".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/documents/books";
    "Downloads/downloads".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/downloads";
    "Music/music".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/music";
    "Pictures/pictures".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/pictures";
    "Videos/videos".source = config.lib.file.mkOutOfStoreSymlink "${wolfNAS}/videos";
    "go/pkg".source = config.lib.file.mkOutOfStoreSymlink "${sharedNAS}/go/pkg";
    ".cargo/registry".source = config.lib.file.mkOutOfStoreSymlink "${sharedNAS}/cargo/registry";
    ".ollama/models".source = config.lib.file.mkOutOfStoreSymlink "${sharedNAS}/ollama";
    #    ".zen".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/zen";
    ".config/btop".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/btop";
    ".config/cmus".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/cmus";
    ".mozilla/firefox/profiles.ini".source = config.lib.file.mkOutOfStoreSymlink "${routerNAS}/dotfiles/firefox";
  };
}