# zed-mcp — Zed editor MCP integration pilot (github + nixos servers).
#
# Uses natsukium/mcp-servers-nix (flake input) to build pinned MCP servers
# and emit a Zed-flavored context_servers fragment. Zed is the fleet's
# official editor (heim persona), so it is the MCP integration target.
#
# Why a sidecar + merge helper instead of writing ~/.config/zed/settings.json
# directly: Zed rewrites settings.json from its own UI, which would make
# every home-manager activation fight the user (and produce the recurring
# ".hm-backup would be clobbered" activation failures seen with other
# runtime-managed files). The fragment below is reproducible; run
# `zed-mcp-merge` once per client to fold it into the live settings.json.
#
# NOTE: the github MCP server needs a GITHUB_PERSONAL_ACCESS_TOKEN.
# Export it in the shell that launches Zed, or wire it through
# mcp-servers-nix's envFile/passwordCommand once a sops key exists.
{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
let
  # flavor "zed" emits {"context_servers": {...}} matching Zed's schema.
  zedConfig = inputs.mcp-servers-nix.lib.mkConfig pkgs {
    programs.github.enable = true;
    programs.nixos.enable = true;
    flavor = "zed";
  };

  zed-mcp-merge = pkgs.writeShellApplication {
    name = "zed-mcp-merge";
    runtimeInputs = with pkgs; [
      jq
      coreutils
    ];
    text = ''
      # Idempotently merge the fleet MCP fragment into Zed's settings.json.
      set -euo pipefail
      SETTINGS="''${ZED_SETTINGS:-$HOME/.config/zed/settings.json}"
      FRAGMENT=${zedConfig}

      mkdir -p "$(dirname "$SETTINGS")"
      [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

      TMP="$(mktemp)"
      jq -s '.[0] * {context_servers: ((.[0].context_servers // {}) * .[1].context_servers)}' \
        "$SETTINGS" "$FRAGMENT" > "$TMP"
      mv "$TMP" "$SETTINGS"
      echo "zed-mcp-merge: github + nixos context servers merged into $SETTINGS"
    '';
  };
in
{
  options.programs.zed-mcp.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Install the Zed MCP integration pilot: a reproducible
      github + nixos context_servers fragment and the zed-mcp-merge helper.
    '';
  };

  config = lib.mkIf (config.programs.zed-mcp.enable && (config.profiles.ai.enable or true)) {
    home.packages = [ zed-mcp-merge ];

    # Reproducible artifact — inspect it, diff it, or merge it manually:
    #   ~/.config/zed/mcp-servers-nix.json
    xdg.configFile."zed/mcp-servers-nix.json".source = zedConfig;
  };
}
