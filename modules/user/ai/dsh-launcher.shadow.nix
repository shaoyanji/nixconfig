# modules/user/ai/dsh-launcher.shadow.nix — the remote client half of the dsh
# launchers, retired from modules/user/ai/dsh-launcher.nix in the deep-slash
# (xs subject nixconfig:deep-slash-clanker-migration).
#
# dsh-remote opens the DeepSeek Harness that `services.dshWeb` published on
# the worker's tailnet name — that service itself is shadowed at
# hosts/delphi/dsh-web.shadow.nix, so this client had a dead target. Reviving
# is a pair: unshadow the service on delphi, then uncomment the blocks below
# back into dsh-launcher.nix.
#
# Deliberately kept live: the `dsh` CLI (scripts/dispatch.sh routes to it)
# and dshLocal — a local harness on a full-tier host owes nothing to delphi.
_: {
  # --- was the dshRemote let binding ----------------------------------------
  # dshRemote = import self.modules."scripts.dsh-remote" {inherit pkgs;};
  # (the script module itself stays — a value library, not a service)

  # --- was in home.packages -------------------------------------------------
  # home.packages = [dshRemote] ++ lib.optional (config.profiles.ai.tier == "full") dshLocal;

  # --- was in home.file alongside the deepseek icon --------------------------
  # ".local/share/applications/dsh-remote.desktop".text = desktop
  #   "DeepSeek Harness (Remote)"
  #   "Open the harness running on the worker"
  #   "dsh-remote"
  #   "ai;agent;dsh;deepseek;remote;browser";
}
