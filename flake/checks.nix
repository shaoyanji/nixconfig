{
  lib,
  systems,
  pkgsFor,
  self,
}:
  lib.genAttrs systems.default (
    system: let
      pkgs = pkgsFor system;
    in
      if !(builtins.elem system systems.checks)
      then {}
      else let
        configs = self.nixosConfigurations;
        assertMsg = condition: message:
          if condition
          then true
          else builtins.throw "host-architecture check failed: ${message}";
        goBackendHosts = builtins.filter (
          host: configs.${host}.config.systemd.services ? go-backend
        ) (builtins.attrNames configs);
      in {
        host-architecture =
          assert assertMsg (configs.thinsandy.config.aiServices.nullclaw.enable) "thinsandy nullclaw must be enabled";
          assert assertMsg (configs.thinsandy.config.aiServices.nullclaw.workspaceRoot == "/var/lib/nullclaw") "thinsandy nullclaw workspaceRoot must be /var/lib/nullclaw";
          assert assertMsg (configs.thinsandy.config.aiServices.nullclaw.environmentFile == "/run/secrets/nullclaw") "thinsandy nullclaw environmentFile must be /run/secrets/nullclaw";

          assert assertMsg (configs.thinsandy.config.aiServices.openclawGateway.enable) "thinsandy openclaw must be enabled";
          assert assertMsg (configs.thinsandy.config.services."openclaw-gateway".environmentFiles == ["/run/secrets/openclaw"]) "thinsandy openclaw environmentFiles must be [/run/secrets/openclaw]";
          assert assertMsg (configs.thinsandy.config.services."openclaw-gateway".config.channels.telegram.tokenFile == "/run/secrets/vanta-telegram") "thinsandy openclaw telegram tokenFile must be /run/secrets/vanta-telegram";
          assert assertMsg (configs.thinsandy.config.aiServices.hermesAgent.enable) "thinsandy hermes must be enabled";
          assert assertMsg (configs.thinsandy.config.services."hermes-agent".environmentFiles == ["/run/secrets/hermes"]) "thinsandy hermes environmentFiles must be [/run/secrets/hermes]";

          assert assertMsg (configs.garnixMachine.config.aiServices.nullclaw.enable) "garnixMachine nullclaw must be enabled";
          assert assertMsg (configs.garnixMachine.config.services.nginx.virtualHosts.default.locations."/".proxyPass == "http://127.0.0.1:3001/") "garnixMachine nginx default proxy must target 127.0.0.1:3001";
          assert assertMsg (configs.garnixMachine.config.aiServices.nullclaw.environmentFile == null) "garnixMachine nullclaw environmentFile must be null";

          assert assertMsg (configs.mtfuji.config.aiServices.nullclaw.enable) "mtfuji nullclaw must be enabled";
          assert assertMsg (configs.mtfuji.config.aiServices.nullclaw.environmentFile == "/run/secrets/nullclaw") "mtfuji nullclaw environmentFile must be /run/secrets/nullclaw";

          assert assertMsg (goBackendHosts == []) "services.go-backend unexpectedly enabled on: ${builtins.toString goBackendHosts}";
          pkgs.runCommand "host-architecture-checks" {} "touch $out";
      }
  )
