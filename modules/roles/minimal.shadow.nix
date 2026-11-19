# modules/roles/minimal.shadow.nix — code removed from modules/roles/minimal.nix,
# plus retired task-level surfaces that have no module home to shadow into.
# A *.shadow.nix is a valid empty module: importing it is a no-op, reviving is
# uncommenting. Addressable as roles.minimal.shadow under .#modules; removed
# packages belong in pkgs.txt — task checks:nix:comments gates this file too.
{...}: {
  # Expired migration dropped from modules/roles/minimal.nix at 887f4364 —
  # home.activation.kgElixirRootCleanup = lib.hm.dag.entryAfter ["writeBoundary"] ''
  #   cacheDir="$HOME/.cache/kg-elixir"
  #   if [ -d "$cacheDir" ]; then rm -rf "$cacheDir"; fi
  # '';

  # --- Retired task surfaces (from taskfiles/dev.yml) -------------------------

  # The flake-update flows once synced garnix.yaml through a `dev:flake:update-garnix`
  # recipe (removed with the file at d5b7baa2). The retired shape, for a revive:
  #
  #   dev:flake:update-garnix:
  #     desc: Rewrite garnix.yaml builds.include from nixosConfigurations
  #     cmds:
  #       - yq -i '.builds.include = []' garnix.yaml
  #       - for host in $(task dev:flake:get-hosts); do yq -i ".builds.include += [\"nixosConfigurations.$host\"]" garnix.yaml; done
  #
  # and each update flow then staged `flake.lock garnix.yaml`. Revive order
  # matters: the garnix.yaml file returns first, the recipe second — the recipe
  # alone leaves `git add` failing on a missing path. Garnix itself lives on as
  # the garnixMachine host + garnix-lib input, not the builds.include file.
  #
  # service-oauth.sh (the old scripts/task/ helper, deleted 6cc689f8): OAuth
  # moved into the owning skill — calendar → `.agents/skills/calendar/scripts/calendar-auth.sh`,
  # google-drive → `.agents/skills/google-drive/scripts/drive-auth.sh`.

  # --- Stopgap dependency installs --------------------------------------------

  # Convention: never `npx`, `cargo install`, or `go install` on a fleet host —
  # the npm/crates/go-module supply chains are the classic virus vector, and a
  # stopgap tool does not earn a declarative pin. Untrusted-ecosystem installs
  # run on the instabox VM instead: `task clanker:job` (scripts/task/clanker.sh)
  # ships the job, `scripts/task/instabox.sh` wakes the box and mints SSH. The
  # retired pattern this replaces: a host-local `pkgs.<lang>-tools` block or a
  # home.activation `npm i -g` line standing up one-off tooling on the host.
}
