{ lib
, systems
, pkgsFor
, self
,
}:
lib.genAttrs systems.default (
  system:
  let
    pkgs = pkgsFor system;
  in
  if !(builtins.elem system systems.checks)
  then { }
  else
    let
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
      checkNullclawFleetHost = host: expected:
        let
          cfg = configs.${host}.config;
        in
        if !(cfg.profiles.aiHost.enable or false)
        then true
        else
          assertMsg cfg.profiles.aiHost.nullclaw.enable "${host} profiles.aiHost.nullclaw.enable must be true"
          && assertMsg cfg.aiServices.nullclaw.enable "${host} aiServices.nullclaw.enable must be true"
          && assertMsg (cfg.aiServices.nullclawDeployment.enable == expected.deploymentEnabled) "${host} nullclawDeployment.enable mismatch"
          && assertMsg (cfg.aiServices.nullclawDeployment.mode == expected.deploymentMode) "${host} nullclawDeployment.mode mismatch"
          && assertMsg (cfg.aiServices.nullclawDeployment.listenHost == expected.listenHost) "${host} nullclawDeployment.listenHost mismatch"
          && assertMsg (cfg.aiServices.nullclawDeployment.listenPort == expected.listenPort) "${host} nullclawDeployment.listenPort mismatch"
          && assertMsg (cfg.aiServices.nullclawDeployment.workspaceRoot == expected.workspaceRoot) "${host} nullclawDeployment.workspaceRoot mismatch"
          && assertMsg (cfg.aiServices.nullclaw.environmentFile == expected.environmentFile) "${host} aiServices.nullclaw.environmentFile mismatch"
          && assertMsg (cfg.aiServices.nullclawDeployment.configJsonSource == expected.configJsonSource) "${host} nullclawDeployment.configJsonSource mismatch"
          && assertMsg
            (
              if expected.configJsonSource != null
              then lib.hasInfix expected.configJsonSource cfg.systemd.services.nullclaw.preStart
              else true
            ) "${host} nullclaw preStart missing expected configJsonSource"
          && assertMsg
            (
              if expected.configJsonSource != null
              then lib.hasInfix "${expected.workspaceRoot}/.nullclaw/config.json" cfg.systemd.services.nullclaw.preStart
              else true
            ) "${host} nullclaw preStart missing expected config.json target"
          && assertMsg
            (
              if expected.nginxDefaultProxy != null
              then cfg.services.nginx.virtualHosts.default.locations."/".proxyPass == expected.nginxDefaultProxy
              else true
            ) "${host} nginx default proxy mismatch";
      goBackendHosts = builtins.filter
        (
          host: configs.${host}.config.systemd.services ? go-backend
        )
        (builtins.attrNames configs);
    in
    # Per-host evaluation checks. Each check forces exactly ONE host's
      # toplevel at EVAL time (interpolating it into a string runs the
      # full module system for that host — assertions included), so
      # `nix build .#checks.<system>.host-eval-<host>` (or a plain `nix
      # eval` of the check) forces just that host's evaluation — CI/garnix
      # can run them in parallel and a failure names the offending host.
      # The former monolithic `host-eval-all` variant passed all ~20 host
      # toplevels as build inputs of a single runCommand, forcing every
      # host eval in one context — it kept getting OOM-killed (CI eval
      # OOM). `nix flake check` still evaluates every per-host check, so
      # nothing is lost — failures just report per host now.
      #
      # Eval-only by design: unsafeDiscardStringContext strips the
      # toplevel's store context so the check derivation does NOT depend
      # on the host closure — building the check is a trivial echo, and
      # no host closure is ever built or downloaded by these checks.
      # (deepSeq is deliberately NOT used: forcing a full NixOS toplevel
      # attrset exceeds the evaluator's call depth.)
    builtins.listToAttrs
      (map
        (host: {
          name = "host-eval-${host}";
          value = pkgs.runCommand "host-eval-${host}" { } ''
            echo "host ${host} evaluated successfully: ${builtins.unsafeDiscardStringContext (toString configs.${host}.config.system.build.toplevel)}"
            touch $out
          '';
        })
        (builtins.attrNames configs))
      // {
      host-architecture =
        assert assertMsg (checkNullclawFleetHost "garnixMachine" nullclawFleetContract.garnixMachine) "garnixMachine nullclaw fleet contract mismatch";
        assert assertMsg (checkNullclawFleetHost "mtfuji" nullclawFleetContract.mtfuji) "mtfuji nullclaw fleet contract mismatch";

        assert assertMsg (goBackendHosts == [ ]) "services.go-backend unexpectedly enabled on: ${builtins.toString goBackendHosts}";
        pkgs.runCommand "host-architecture-checks" { } "touch $out";

      docs-site =
        pkgs.runCommand "docs-site" { } ''
          mkdir -p "$out"
          ls "${self.docsSite}/index.html" > "$out/index.html"
        '';
    }
)
