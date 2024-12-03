{ pkgs,config, ... }:

{
  imports = [ 
    ./global/heim.nix
    ./hyprland.nix
    ./hypr
  ];
  home.packages = with pkgs; [
  ];
  home.file = {
    "Documents/Obsidian-Git-Sync".source = config.lib.file.mkOutOfStoreSymlink "/mnt/y/documents/Obsidian-Git-Sync";
    "Documents/work".source = config.lib.file.mkOutOfStoreSymlink "/mnt/y/documents/work";
    #    "Documents/nixconfig".source = config.lib.file.mkOutOfStoreSymlink "/mnt/y/documents/nixconfig";
    #    "Documents/books".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/documents/books";
    #    "Downloads/downloads".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/downloads";
    #    "Music/music".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/music";
    #    "Pictures/pictures".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/pictures";
    #    "Videos/videos".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/videos";
    ".local/.bin".source = config.lib.file.mkOutOfStoreSymlink "/mnt/x/bin-x86";
    ".ollama/models".source = config.lib.file.mkOutOfStoreSymlink "/mnt/x/ollama";
    ".zen".source = config.lib.file.mkOutOfStoreSymlink "/mnt/y/dotfiles/zen";
    ".config/btop".source = config.lib.file.mkOutOfStoreSymlink "/mnt/y/dotfiles/btop";
    ".config/cmus".source = config.lib.file.mkOutOfStoreSymlink "/mnt/y/dotfiles/cmus";
  };
   home.sessionVariables = {
    #    PATH = "/nix/var/nix/profiles/default/bin:$HOME/.local/.bin/:$PATH";
   };

}
