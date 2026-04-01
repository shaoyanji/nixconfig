# Common shell hooks shared across devShells
{pkgs}: {
  # Basic hook with common tools initialization
  basic = ''
    eval "$(${pkgs.zoxide}/bin/zoxide init bash)"
    eval "$(${pkgs.fzf}/bin/fzf --bash)"
    eval "$(${pkgs.go-task}/bin/task --completion bash)"
    eval "$(${pkgs.direnv}/bin/direnv hook bash)"
  '';

  # Full hook with starship and aliases
  full = ''
    eval "$(${pkgs.zoxide}/bin/zoxide init bash)"
    eval "$(${pkgs.fzf}/bin/fzf --bash)"
    eval "$(${pkgs.go-task}/bin/task --completion bash)"
    eval "$(${pkgs.direnv}/bin/direnv hook bash)"
    eval "$(${pkgs.starship}/bin/starship init bash)"

    # File sharing helpers
    0file() { curl -F"file=@$1" https://envs.sh ; }
    0pb() { curl -F"file=@-;" https://envs.sh ; }
    0url() { curl -F"url=$1" https://envs.sh ; }
    0short() { curl -F"shorten=$1" https://envs.sh ; }

    # Eza aliases
    alias l='${pkgs.eza}/bin/eza -lahF --color=auto --icons --sort=size --group-directories-first'
    alias lss='${pkgs.eza}/bin/eza -hF --color=auto --icons --sort=size --group-directories-first'
    alias la='${pkgs.eza}/bin/eza -ahF --color=auto --icons --sort=size --group-directories-first'
    alias ls='${pkgs.eza}/bin/eza -lhF --color=auto --icons --sort=Name --group-directories-first'
    alias lst='${pkgs.eza}/bin/eza -lahFT --color=auto --icons --sort=size --group-directories-first'
    alias lt='${pkgs.eza}/bin/eza -aT --icons --group-directories-first --color=auto --sort=size'

    # Tool aliases
    alias cat='${pkgs.bat}/bin/bat -p'
    alias grep='${pkgs.ripgrep}/bin/rg'
  '';

  # Minimal hook (no init scripts)
  minimal = "";

  # Greeting with cowsay and lolcat
  greeting = ''
    echo "$GREETING" | ${pkgs.cowsay}/bin/cowsay | ${pkgs.lolcat}/bin/lolcat
  '';

  # Nushell hook
  nushell = ''
    ${pkgs.nushell}/bin/nu
  '';
}
