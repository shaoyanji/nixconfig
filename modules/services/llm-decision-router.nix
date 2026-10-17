# LLM and Decision Model Router Service Module
# Routes /v1/chat/completions to local llama-swap (Qwen3.6-35B-A3B)
# Routes /v1/decisions to TypeSafe Jev (cloud) with automatic fallback to local Laya (:8090)
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.llm-decision-router;

  routerPkg = pkgs.buildGoModule {
    pname = "llm-decision-router";
    version = "0.1.0";
    src = ./llm-decision-router;
    vendorHash = null;
    env.CGO_ENABLED = 0;
  };
in {
  options.services.llm-decision-router = {
    enable = lib.mkEnableOption "LLM & Decision Model Router for SubZeroClaw and fleet agents";

    package = lib.mkOption {
      type = lib.types.package;
      default = routerPkg;
      description = "The router binary package.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "TCP port to listen on.";
    };

    bind = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "IP address to bind the router to.";
    };

    llmUpstream = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8080";
      description = "Upstream base URL for generative chat completions (llama-swap).";
    };

    typesafeEndpoint = lib.mkOption {
      type = lib.types.str;
      default = "https://api.typesafe.ai/v1/systemone";
      description = "TypeSafe Jev System One cloud endpoint.";
    };

    layaEndpoint = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8090/v1/systemone";
      description = "Local Laya decision model endpoint.";
    };

    defaultDecisionModel = lib.mkOption {
      type = lib.types.str;
      default = "jev-latest";
      description = "Default model identifier sent to TypeSafe Jev if unspecified.";
    };

    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "qwen3.6-35b-a3b";
      description = "Default generative model for chat completions when the request omits a model or uses a policy: prefix. SubZeroClaw follows this default.";
    };

    fallbackToLocal = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Fallback to local Laya on TypeSafe network error or failure.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.llm-decision-router = {
      description = "LLM & Decision Model Router for SubZeroClaw";
      after = [
        "network.target"
        "llama-swap.service"
        "laya-serve.service"
      ];
      wants = [
        "llama-swap.service"
        # Deliberately NOT laya-serve: wanting it would start Laya at boot
        # and defeat on-demand. The router falls back to Laya via the socket
        # when TypeSafe is unreachable; a request through it activates Laya.
      ];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/llm-decision-router";
        Restart = "always";
        RestartSec = 3;
        Environment = [
          "PORT=${toString cfg.port}"
          "BIND=${cfg.bind}"
          "LLM_UPSTREAM=${cfg.llmUpstream}"
          "TYPESAFE_ENDPOINT=${cfg.typesafeEndpoint}"
          "LAYA_ENDPOINT=${cfg.layaEndpoint}"
          "DEFAULT_DECISION_MODEL=${cfg.defaultDecisionModel}"
          "DEFAULT_MODEL=${cfg.defaultModel}"
          "FALLBACK_TO_LOCAL=${
            if cfg.fallbackToLocal
            then "true"
            else "false"
          }"
        ];
      };
    };
  };
}
