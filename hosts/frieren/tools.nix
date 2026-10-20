{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption;
  cfg = config.services.nasTools;

  wikisearch = import ../../modules/scripts/wikisearch.nix {inherit pkgs;};

  freebuff-headless = import ../../modules/scripts/freebuff-headless.nix {inherit pkgs;};

  qmdEisenEmbedSync = import ../../modules/scripts/qmd-eisen-embed-sync.nix {inherit pkgs;};

  # `dsh web` prints a tokenised URL and opens it; the bare 127.0.0.1:3080
  # answers 401 by design ("reopen the URL printed by dsh web"). This is the
  # desktop entry for the harness, so it is reachable from the launcher instead
  # of a terminal. It refuses to start a second server — two instances fight
  # over the port, and only the first one's printed URL carries a valid token.
  dshWeb = pkgs.writeShellApplication {
    name = "dsh-web";
    runtimeInputs = [pkgs.llm-agents.dsh pkgs.iproute2 pkgs.gawk pkgs.gnugrep pkgs.coreutils];
    text = ''
      port="''${DSH_PORT:-3080}"
      if ss -ltnH 2>/dev/null | awk '{print $4}' | grep -qE "[:.]''${port}$"; then
        echo "dsh web is already serving on port $port." >&2
        echo "Its tokenised URL is in the terminal that started it." >&2
        echo "http://127.0.0.1:$port on its own returns 401 by design." >&2
        exit 0
      fi
      # No --no-open: the app opens the tokenised URL itself, which is the only
      # form that authenticates.
      exec dsh web
    '';
  };

  dshDesktop = pkgs.makeDesktopItem {
    name = "dsh-web";
    desktopName = "DeepSeek Harness";
    genericName = "Agent Harness";
    comment = "Start the DeepSeek Harness and open its web UI";
    # Double quotes, not single: the desktop-entry spec does not treat `'` as a
    # quote, so `--title 'DeepSeek Harness'` fails desktop-file-validate with
    # "reserved character ''' outside of a quote" and takes the whole frieren
    # toplevel down (caught by CI, not by eval).
    exec = "kitty --title \"DeepSeek Harness\" -e dsh-web";
    icon = "utilities-terminal";
    categories = ["Development" "Utility"];
    keywords = ["ai" "agent" "harness" "dsh" "deepseek"];
    terminal = false;
  };

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
      lightTools ++ [dshWeb dshDesktop pkgs.plocate] ++ lib.optionals cfg.enableHeavy heavyTools;

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
      ];
    };
  };
}
