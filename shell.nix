# let
#   nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-unstable";
#   pkgs = import nixpkgs { config = {}; overlays = []; };
# in
{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell
# pkgs.mkShellNoCC 
{
  packages = with pkgs; [
    cowsay
    lolcat
    oh-my-posh 
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
    # minimalistic jobby tools
    helix
    fastfetch
    hyperfine
    lf
  # aitools
    ollama
    #aichat
    tgpt
    #sops
    #mods
  # pdf workflow
    # pandoc
    # texlive.combined.scheme-small
    # tgpt
    # pdfcpu
    # poppler_utils
    # wkhtmltopdf
  ];
  GREETING = "Hello, Nix!";
   shellHook = ''
   #zsh
   export EDITOR='hx'
   #  
   #   alias loadapi='export $(sops -d $HOME/secrets/api.env)'
   #   alias unloadapi='export $(cat $HOME/secrets/api.env)'
   #   export SOPS_AGE_KEY_FILE="/Volumes/FRITZ.NAS/External-USB3-0-01/documents/age-key.txt"
   #   export SOPS_AGE_RECIPIENT="age1tsv2lurpjzyx9ng6hcc4dff23lvv7tqkyyxz5zlpx32egu2c9vfql9m008"
   eval "$(zoxide init bash)"
   eval "$(fzf --bash)"
   eval "$(oh-my-posh init bash --config ~/.oh-my-posh/cat.omp.json)"
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
