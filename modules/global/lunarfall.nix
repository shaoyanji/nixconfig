{ pkgs,config, ... }:

{
  imports = [ 
    ./heim.nix
  ];
  
  nixpkgs.config.allowUnfree = true;

  #nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #           "obsidian"
  #         ];

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
  ];
 # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    ".ollama/models".source = config.lib.file.mkOutOfStoreSymlink "/mnt/x/ollama";
    ".config/btop".source = config.lib.file.mkOutOfStoreSymlink "/mnt/x/dotfiles/btop";
    ".config/cmus".source = config.lib.file.mkOutOfStoreSymlink "/mnt/x/dotfiles/cmus";
    "Documents/Obsidian-Git-Sync".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/documents/Obsidian-Git-Sync";
    "Documents/work".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/documents/work";
    "Documents/books".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/books";
    "Documents/projects".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/projects";
    "Downloads/downloads".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/downloads";
    "Music/music".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/music";
    "Pictures/pics".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/pics";
    "Videos/video".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/video";
    ".mozilla/firefox/profiles.ini".source = config.lib.file.mkOutOfStoreSymlink "/mnt/z/dotfiles/profiles.ini";
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;
   # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600
    # '';
  };

   home.sessionVariables = {
      XDG_DATA_DIRS="$XDG_DATA_DIRS:$HOME/.nix-profile/share:/nix/var/nix/profiles/default/share";
      PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH:$HOME/go/bin:$HOME/.cargo/bin";
   };
}
