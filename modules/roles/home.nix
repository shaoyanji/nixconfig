# User desktop role, assembled from the feature list in `fleet.hmUserFeatures`.
# An import the feature list does not take is option surface no gate pays for;
# why that is the unit of eval cost: AGENTS.nix note `eval-cost-ladder`.
{
  self,
  lib,
  pkgs,
  user,
  # Set by `fleet.dankShell.enable` through modules/global/nixos.nix. Default
  # true keeps every darwin/demo/home host on the DMS imports.
  dankShell ? true,
  # `fleet.hmUserFeatures` reaches here the same way `dankShell` does: a module
  # argument, because reading `config.fleet…` inside `imports` is the recursion
  # the option exists to avoid.
  hmUserFeatures ? user.hmFeatures,
  ...
}: let
  has = f: lib.elem f hmUserFeatures;

  # Feature → module set. imports is one concatMap over hmUserFeatures, so the
  # fleet's declared feature order is the import order and a name the table
  # lacks contributes nothing (or []).
  features = {
    systemd-policy = [self.modules."systemd-policy"];
    shell = [self.modules."shell"];
    dev = [self.modules."dev"];
    ai = [
      self.modules."user.ai.antigravity-cli"
      self.modules."user.selector-daemon"
    ];
    browser = [self.modules."zen" self.modules."aria2"];
    media = [
      self.modules."user.desktop.multimedia"
      self.modules."kitty"
    ];
    # Imported unconditionally in the old file (`a pkgs`-dependent import reads
    # `config` and recurses); niri.nix gates its own body with mkIf on Linux,
    # because a Wayland compositor has no aarch64-darwin counterpart and its
    # swayidle dependency is not packaged for darwin — which failed EVALUATION,
    # not just the build, on cassini. A host that owns its own compositor drops
    # the feature rather than redefining the same options twice.
    desktop =
      [self.modules."user.desktop.suite"]
      ++ lib.optionals dankShell [self.modules."user.desktop.niri"];
  };

  programsBase = {
    home-manager.enable = true;
    nix-your-shell.enable = true;
  };
  # `optionalAttrs`, not `mkIf`: `selectorDaemon` is declared by a module the
  # `ai` feature imports, and a `programs.selectorDaemon.enable = lib.mkIf …` is
  # still checked against an option that does not exist once the feature is off
  # (measured: "The option programs.selectorDaemon does not exist").
  programsAi = {
    selectorDaemon.enable = lib.mkDefault true;
  };
in {
  imports =
    [self.modules."roles.minimal"]
    ++ lib.concatMap (f: features.${f} or []) hmUserFeatures;

  # No resident knowledge-graph sidecar: it answered 25 ms faster than the
  # content-keyed graph file and cost 27 MB of BEAM to do it, so it is gone
  # (flake/daemons.nix, docs/nix-patterns.md). `iets` covers the eval-on-miss.
  #
  # The selector's bargain: `q.sh --question` asks the resident stage 1 and
  # falls back to the interpreter, so a host without it answers the same
  # question ~70 ms slower instead of not answering.
  programs = programsBase // lib.optionalAttrs (has "ai") programsAi;

  home = {
    username = user.name;
    # mkDefault: on darwin the target's own default is /Users/<user>, and two
    # normal-tier definitions conflict (cassini failed its host gate on exactly
    # that). Linux has no competing definition, so the value still applies.
    homeDirectory = lib.mkDefault user.home;

    sessionPath = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      "/run/wrappers/bin"
    ];

    sessionVariables = {
    };
  };
}
