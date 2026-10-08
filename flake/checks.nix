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
      goBackendHosts =
        builtins.filter
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
          value = pkgs.runCommand "host-eval-${host}" {} ''
            echo "host ${host} evaluated successfully: ${builtins.unsafeDiscardStringContext (toString configs.${host}.config.system.build.toplevel)}"
            touch $out
          '';
        })
        (builtins.attrNames configs))
      // {
        host-architecture = assert assertMsg (goBackendHosts == []) "services.go-backend unexpectedly enabled on: ${builtins.toString goBackendHosts}";
          pkgs.runCommand "host-architecture-checks" {} "touch $out";

        docs-site = pkgs.runCommand "docs-site" {} ''
          mkdir -p "$out"
          ls "${self.docsSite}/index.html" > "$out/index.html"
        '';
      }
)
