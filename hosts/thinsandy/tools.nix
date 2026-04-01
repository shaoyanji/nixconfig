{
  pkgs,
  lib,
  ...
}: let
  researchPython = pkgs.python3.withPackages (ps:
    with ps; [
      neo4j
      pytz
      firecrawl-py
      pydantic
    ]);

  commonTools = with pkgs; [
    qwen-code
    codex
    cowsay
    figlet
    graphviz
    vim
    wget
    git
    btop
    btrfs-progs
    f2fs-tools
    go
    yq-go
    ddgr
    bat
    fd
    sqlite
    gh
    fzf
    delta
    httpie
    ncdu
    tree
    unzip
    xxd
    lsof
    pv
    miller
    glow
    sd
    hyperfine
    tldr
    watch
    neo4j
    typst
    pup
    htmlq
    go-task
    gnumake
    shellcheck
    entr
    file
    rsync

    uv
    (lib.hiPrio researchPython)
  ];
in {
  environment.systemPackages = commonTools;
  # _module.args.commonServicePath = commonTools;
}
