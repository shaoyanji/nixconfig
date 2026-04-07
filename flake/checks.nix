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
        nullclawFleetContract = {
          garnixMachine = {
            deploymentEnabled = true;
            deploymentMode = "config-json";
            listenHost = "127.0.0.1";
            listenPort = 3001;
            workspaceRoot = "/var/lib/nullclaw";
            environmentFile = null;
            configJsonSource = "/run/secrets/nullclaw-config";
            nginxDefaultProxy = "http://127.0.0.1:3000/";
          };
          mtfuji = {
            deploymentEnabled = true;
            deploymentMode = "env-file";
            listenHost = "127.0.0.1";
            listenPort = 3001;
            workspaceRoot = "/var/lib/nullclaw";
            environmentFile = "/run/secrets/nullclaw";
            configJsonSource = null;
            nginxDefaultProxy = null;
          };
        };
        checkNullclawFleetHost = host: expected: let
          cfg = configs.${host}.config;
        in
          assertMsg (cfg.profiles.aiHost.enable) "${host} profiles.aiHost must be enabled"
          && assertMsg (cfg.profiles.aiHost.nullclaw.enable) "${host} profiles.aiHost.nullclaw.enable must be true"
          && assertMsg (cfg.aiServices.nullclaw.enable) "${host} aiServices.nullclaw.enable must be true"
          && assertMsg (cfg.aiServices.nullclawDeployment.enable == expected.deploymentEnabled) "${host} nullclawDeployment.enable mismatch"
          && assertMsg (cfg.aiServices.nullclawDeployment.mode == expected.deploymentMode) "${host} nullclawDeployment.mode mismatch"
          && assertMsg (cfg.aiServices.nullclawDeployment.listenHost == expected.listenHost) "${host} nullclawDeployment.listenHost mismatch"
          && assertMsg (cfg.aiServices.nullclawDeployment.listenPort == expected.listenPort) "${host} nullclawDeployment.listenPort mismatch"
          && assertMsg (cfg.aiServices.nullclawDeployment.workspaceRoot == expected.workspaceRoot) "${host} nullclawDeployment.workspaceRoot mismatch"
          && assertMsg (cfg.aiServices.nullclaw.environmentFile == expected.environmentFile) "${host} aiServices.nullclaw.environmentFile mismatch"
          && assertMsg (cfg.aiServices.nullclawDeployment.configJsonSource == expected.configJsonSource) "${host} nullclawDeployment.configJsonSource mismatch"
          && assertMsg (
            if expected.configJsonSource != null
            then lib.hasInfix expected.configJsonSource cfg.systemd.services.nullclaw.preStart
            else true
          ) "${host} nullclaw preStart missing expected configJsonSource"
          && assertMsg (
            if expected.configJsonSource != null
            then lib.hasInfix "${expected.workspaceRoot}/.nullclaw/config.json" cfg.systemd.services.nullclaw.preStart
            else true
          ) "${host} nullclaw preStart missing expected config.json target"
          && assertMsg (
            if expected.nginxDefaultProxy != null
            then cfg.services.nginx.virtualHosts.default.locations."/".proxyPass == expected.nginxDefaultProxy
            else true
          ) "${host} nginx default proxy mismatch";
        goBackendHosts = builtins.filter (
          host: configs.${host}.config.systemd.services ? go-backend
        ) (builtins.attrNames configs);
      in {
        host-architecture =
          assert assertMsg (configs.thinsandy.config.aiServices.nullclaw.enable) "thinsandy nullclaw must be enabled";
          assert assertMsg (configs.thinsandy.config.aiServices.nullclaw.workspaceRoot == "/var/lib/nullclaw") "thinsandy nullclaw workspaceRoot must be /var/lib/nullclaw";
          assert assertMsg (configs.thinsandy.config.aiServices.nullclaw.environmentFile == "/run/secrets/nullclaw") "thinsandy nullclaw environmentFile must be /run/secrets/nullclaw";

          assert assertMsg (configs.thinsandy.config.services."hermes-agent".enable) "thinsandy hermes must be enabled";
          assert assertMsg (
            configs.thinsandy.config.services."hermes-agent".environmentFiles
            == ["/run/secrets/hermes" "/run/secrets/ai-services-shared-env"]
          ) "thinsandy hermes environmentFiles must be [/run/secrets/hermes /run/secrets/ai-services-shared-env]";

          assert assertMsg (checkNullclawFleetHost "garnixMachine" nullclawFleetContract.garnixMachine) "garnixMachine nullclaw fleet contract mismatch";
          assert assertMsg (checkNullclawFleetHost "mtfuji" nullclawFleetContract.mtfuji) "mtfuji nullclaw fleet contract mismatch";

          assert assertMsg (goBackendHosts == []) "services.go-backend unexpectedly enabled on: ${builtins.toString goBackendHosts}";
          pkgs.runCommand "host-architecture-checks" {} "touch $out";

        ai-host-fleet-contract =
          assert assertMsg (checkNullclawFleetHost "garnixMachine" nullclawFleetContract.garnixMachine) "garnixMachine nullclaw fleet contract mismatch";
          assert assertMsg (checkNullclawFleetHost "mtfuji" nullclawFleetContract.mtfuji) "mtfuji nullclaw fleet contract mismatch";
          pkgs.runCommand "ai-host-fleet-contract" {} "touch $out";

        docs-site =
          pkgs.runCommand "docs-site" {} ''
            mkdir -p "$out"
            ls "${self.docsSite}/index.html" > "$out/index.html"
          '';

        manifest-helper =
          pkgs.runCommand "manifest-helper" {
            buildInputs = [ pkgs.jq ];
            src = ../.;
          } ''
            mkdir -p "$out"
            bash "$src/scripts/task/ai-host-manifest.sh" list > "$out/hosts.txt"
            test -s "$out/hosts.txt"
          '';
      }
  )
