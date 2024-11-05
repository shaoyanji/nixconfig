# let
#   nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-unstable";
#   pkgs = import nixpkgs { config = {}; overlays = []; };
# in
{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell
# pkgs.mkShellNoCC 
{
  nativeBuildInputs = with pkgs; [
  ];
  packages = with pkgs; [
    cowsay
    lolcat
    (python310.withPackages (ps: with ps; [
      flask
      fuzzywuzzy
      markdown2
      python-dotenv
    ]))
    #    oh-my-posh 
    fzf
    zoxide
    bat
    eza
    ripgrep
  # base tools 
	# dev tools
	    #	duckdb
	    #	xcbuild
	    #	coreutils
      #	wkhtmltopdf
	# languages
	    #	python3
	    #	nodejs
	    #	nodePackages.node2nix
	    #	go
  # shell tools
    fastfetch
    hyperfine
    lf
  # aitools
    #ollama
    #aichat
    tgpt
    #sops
    #mods
  ];
  GREETING = "Hello, Nix!";
   shellHook = /*bash*/ ''
   #zsh
   eval "$(zoxide init bash)"
   eval "$(fzf --bash)"
   0file() { curl -F"file=@$1" https://envs.sh ; }
   0pb() { curl -F"file=@-;" https://envs.sh ; }
   0url() { curl -F"url=$1" https://envs.sh ; }
   0short() { curl -F"shorten=$1" https://envs.sh ; }
   alias l='eza -lahF --color=auto --icons --sort=size --group-directories-first'
   alias lss='eza -hF --color=auto --icons --sort=size --group-directories-first'
   alias la='eza -ahF --color=auto --icons --sort=size --group-directories-first'
   alias ls='eza -lhF --color=auto --icons --sort=Name --group-directories-first'
   alias lst='eza -lahFT --color=auto --icons --sort=size --group-directories-first'
   alias lt='eza -aT --icons --group-directories-first --color=auto --sort=size'
   alias cat='bat'
   alias grep='rg'
   echo $GREETING | cowsay | lolcat
   '';
}
