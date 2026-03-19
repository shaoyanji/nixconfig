{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # Core
    codex
    vim
    wget
    git
    btop
    btrfs-progs
    f2fs-tools
    go

    # Agent shopping list
    yq # YAML/TOML/JSON processing
    ddgr # DuckDuckGo search CLI (web search fallback)
    bat # cat with syntax highlighting
    fd # fast file finder
    sqlite # database access
    gh # GitHub CLI

    # Nice to have
    fzf # fuzzy finder (pairs well with fd/bat)
    delta # better git diffs
    httpie # friendly HTTP client for APIs
    ncdu # disk usage explorer
    tree # directory tree view
    unzip # archive handling
    xxd # hex dump
    lsof # list open files
    pv # pipe viewer (progress bars)
    miller # mlr — CSV/JSON/log processing
    glow # markdown renderer in terminal
    sd # sed alternative (regex find/replace)
    hyperfine # CLI benchmarking
    tldr # simplified man pages
    watch # run commands periodically

    # Next
    ripgrep
    tmux
    tokei
    jq
    tgpt

    uv
    (python3.withPackages (ps:
      with ps; [
        neo4j
        pytz
        firecrawl-py
        pydantic
      ]))
    neo4j
  ];
}
