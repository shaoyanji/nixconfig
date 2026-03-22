{pkgs, ...}: let
  researchPython = pkgs.python3.withPackages (ps:
    with ps; [
      neo4j
      pytz
      firecrawl-py
      pydantic
    ]);

  commonTools = with pkgs; [
    codex
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
    uv
    researchPython
    neo4j
    typst
    pup
    htmlq
    go-task
  ];
in {
  environment.systemPackages = commonTools;
  _module.args.commonServicePath = commonTools;
}
