{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption;
  cfg = config.services.nasTools;

  wikisearch = import ../../modules/scripts/wikisearch.nix {inherit pkgs;};

  # Retrieval an agent can afford: fan-out + fusion + a token gate, over the
  # same archives `wikisearch` queries. Both stay — `wikisearch` is the raw
  # Kiwix CLI an operator types, `wiki-ask` is what an agent calls.
  wikiAsk = import ../../modules/scripts/wiki-ask.nix {inherit pkgs;};

  freebuff-headless = import ../../modules/scripts/freebuff-headless.nix {inherit pkgs;};

  qmdEisenEmbedSync = import ../../modules/scripts/qmd-eisen-embed-sync.nix {inherit pkgs;};

  # The dsh launchers (local harness + remote client + desktop entries) come
  # from the home-manager chain: modules/user/ai/dsh-launcher.nix.
  # Dormant by default (`enableHeavy` is not set on any host). Deliberately no
  # Neo4j server here: the knowledge graph is a generated projection, and a JVM
  # heap competes with the NAS page cache (AGENTS.nix `p3-graph-query`). If an external
  # graph instance is ever needed, feed it `nix eval --raw .#knowledgeGraph.cypher`.
  heavyTools = with pkgs; [
    go
    uv
    gh
    typst
    (pkgs.python3.withPackages (
      ps:
        with ps; [
          pytz
          firecrawl-py
          pydantic
        ]
    ))
  ];

  lightTools = with pkgs; [
    wikisearch
    wikiAsk
    freebuff-headless
    qmdEisenEmbedSync
    # TOON is the agent-facing projection for the sentinel ledger and other
    # uniform records. Present system-wide so root/systemd helpers can encode
    # without assuming a user profile on PATH.
    pkgs.llm-agents.toon
    # frieren is the fleet's Freebuff mainframe: the TUI runs here and
    # clients reach it via freebuff-remote/freebuff-terminal (SSH).
    pkgs.llm-agents.freebuff
    # hermes-agent — Fryuni fork of the 2026-09 teardown; lives on the
    # mainframe only (see fleet closure policy in ~/HANDOFF.md).
    pkgs.llm-agents.hermes-agent
    # deepseek-harness (dsh) — open-source agent harness from DeepSeek AI
    pkgs.llm-agents.dsh
    simplex-chat
    (python3.withPackages (ps:
      with ps; [
        websockets
        requests
        aiohttp
      ]))
    skills
    cowsay
    figlet
    graphviz
    vim
    wget
    git
    btop
    btrfs-progs
    f2fs-tools
    yq-go
    ddgr
    bat
    fd
    sqlite
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
    pup
    htmlq
    gnumake
    shellcheck
    entr
    file
    rsync
    jq
    himalaya
  ];
in {
  options.services.nasTools = {
    enableHeavy = mkEnableOption "Heavy dev tools (go, uv, gh, typst, python research env)";
  };

  config = {
    environment.systemPackages =
      lightTools ++ [pkgs.plocate] ++ lib.optionals cfg.enableHeavy heavyTools;

    # --- Fast Filesystem Indexing (plocate) ---
    services.locate = {
      enable = true;
      package = pkgs.plocate;
      interval = "hourly";
      # services.locate.localuser was removed upstream (findutils locate dropped);
      # the plocate updatedb service runs as root regardless.
      pruneFS = [
        "tmpfs"
        "proc"
        "sysfs"
        "devpts"
        "nfs"
        "nfs4"
        "cifs"
      ];
      pruneNames = [
        ".git"
        ".hg"
        ".svn"
        ".snapshots"
      ];
      prunePaths = [
        "/tmp"
        "/var/tmp"
        "/nix/store"
        "/.snapshots"
        "/mnt"
        "/Volumes"
      ];
    };
  };
}
