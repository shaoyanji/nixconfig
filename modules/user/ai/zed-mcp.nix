# zed-mcp — Zed editor MCP integration pilot (github + nixos servers).
{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: let
  # flavor "zed" emits {"context_servers": {...}} matching Zed's schema.
  zedConfig = inputs.mcp-servers-nix.lib.mkConfig pkgs {
    programs = {
      # Active MCP servers
      nixos.enable = true;
      tavily.enable = true;

      # Available on-demand (disabled to minimize context overhead & process footprint)
      deepl.enable = false;
      fetch.enable = false;
      filesystem.enable = false;
      git.enable = false;
      github.enable = false;
      gsheets.enable = false;
      home-assistant.enable = false;
      memory.enable = false;
      notion.enable = false;
      playwright.enable = false;
      sequential-thinking.enable = false;
    };
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
      echo "zed-mcp-merge: active MCP context servers (nixos + tavily) merged into $SETTINGS"
    '';
  };
in {
  options.programs.zed-mcp.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Install the Zed MCP integration: a reproducible
      context_servers fragment and the zed-mcp-merge helper.
    '';
  };

  config = lib.mkIf (config.programs.zed-mcp.enable && (config.profiles.ai.enable or true)) {
    home.packages = [zed-mcp-merge];

    # Reproducible artifact — inspect it, diff it, or merge it manually:
    #   ~/.config/zed/mcp-servers-nix.json
    xdg.configFile."zed/mcp-servers-nix.json".source = zedConfig;
  };
}
