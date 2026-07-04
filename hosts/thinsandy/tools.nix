{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.services.thinsandyTools;
  heavyTools = with pkgs; [
    go
    uv
    gh
    neo4j
    typst
    (pkgs.python3.withPackages (ps: with ps; [neo4j pytz firecrawl-py pydantic]))
  ];
  lightTools = with pkgs; [
    skills
    cowsay figlet graphviz
    vim wget git btop
    btrfs-progs f2fs-tools
    yq-go ddgr bat fd sqlite
    fzf delta httpie ncdu tree
    unzip xxd lsof pv miller glow
    sd hyperfine tldr watch
    pup htmlq
    gnumake shellcheck entr file rsync jq
    himalaya
  ];
in {
  options.services.thinsandyTools = {
    enableHeavy = mkEnableOption "Heavy dev tools (go, uv, gh, neo4j, python research env)";
  };

  config = {
    environment.systemPackages = lightTools ++ lib.optionals cfg.enableHeavy heavyTools;
  };
}
