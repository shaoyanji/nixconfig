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
