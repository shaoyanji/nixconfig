# Stage-2 nushell configuration (UI, history, completions).
#
# This file is the source of truth for these settings; modules/shell/nushell.nix
# only `source`s it plus the interpolated pkgs paths it cannot know about. A
# nushell change is therefore a `.nu` diff that a shell can parse, not a Nix
# string that only the Nix parser sees.

let carapace_completer = {|spans|
  carapace $spans.0 nushell $spans | from json
}

$env.config = {
  show_banner: false
  edit_mode: 'vi'
  history: {
    max_size: 100_000
    sync_on_enter: true
    file_format: "sqlite"
    isolation: false
  }
  completions: {
    case_sensitive: false
    quick: true
    partial: true
    algorithm: "fuzzy"
    external: {
      enable: true
      max_results: 100
      completer: $carapace_completer
    }
  }
}

# starship: a repo on the NAS automount answers `git status` in seconds, and
# starship has no per-directory module switch. STARSHIP_CONFIG is that switch —
# the prompt re-reads it on every render — so point it at the config without
# `git_status` while the cwd is under the mount. Bash twin:
# modules/shell/default.nix.
#
# A `pre_prompt` hook, not `env_change.PWD`: it runs on every prompt (before
# starship's PROMPT_COMMAND draws) so no `cd` hook has to fire and nothing can go
# stale, and `load-env` inside a hook block is preserved — the direnv integration
# in the generated config uses exactly this hook type and this call.
def _starship_config_for [pwd: string] {
  if $pwd == "/Volumes/data" or ($pwd | str starts-with "/Volumes/data/") {
    $"($env.HOME)/.config/starship-no-git.toml"
  } else {
    $"($env.HOME)/.config/starship.toml"
  }
}

$env.config.hooks = ($env.config.hooks? | default {})
$env.config.hooks.pre_prompt = (
  $env.config.hooks.pre_prompt?
  | default []
  | append {|| load-env {STARSHIP_CONFIG: (_starship_config_for $env.PWD)} }
)
