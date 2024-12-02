{ pkgs,config, ... }:

{
  imports = [ 
    ./heim.nix
    ./hyprland.nix
    ./hypr
  ];
  home.packages = with pkgs; [
  ];
  home.file = {
    #    "Documents/Obsidian-Git-Sync".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/documents/Obsidian-Git-Sync";
    #    "Documents/work".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/documents/work";
    #    "Documents/nixconfig".source = config.lib.file.mkOutOfStoreSymlink "/mnt/y/documents/nixconfig";
    #    "Documents/books".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/documents/books";
    #    "Downloads/downloads".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/downloads";
    #    "Music/music".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/music";
    #    "Pictures/pictures".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/pictures";
    #    "Videos/videos".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/videos";
    ".local/.bin".source = config.lib.file.mkOutOfStoreSymlink "/mnt/x/bin-x86";
    ".ollama/models".source = config.lib.file.mkOutOfStoreSymlink "/mnt/x/ollama";
    ".config/.zen".source = config.lib.file.mkOutOfStoreSymlink "/mnt/x/dotfiles/zen";
    ".config/mnt/x/dotfiles/btop".source = config.lib.file.mkOutOfStoreSymlink "/mnt/x/dotfiles/btop";
    ".config/mnt/x/dotfiles/cmus".source = config.lib.file.mkOutOfStoreSymlink "/mnt/x/dotfiles/cmus";
  };
   home.sessionVariables = {
    #    PATH = "/nix/var/nix/profiles/default/bin:$HOME/.local/.bin/:$PATH";
   };

}
