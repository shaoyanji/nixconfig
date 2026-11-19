# =============================================================================
# dispatch.nu — the task surface over the workflow modules
#
# Colon names are the task vocabulary: `nu-task jobby:coverletter:render` is
# the same command as `jobby coverletter render` — nushell's space-subcommand
# form of the taskfile `jobby:coverletter:render` recipe. `nutasks` is the
# `--list` analogue and `nu-task` the runner; modules/shell/nushell.nix wires
# `nu-run` onto both, so `nu-run x:y` runs the task and a bare `nu-run` lists.
#
# nushell has no call-by-name, so nu-task re-enters `nu -c` on the same
# config/env paths nu-run pins — one extra startup for name resolution.
# =============================================================================

# One argument → one word in the emitted command line. Safe-charset words go
# bare so nu's own typing still applies (a `float` param sees `0.5`, not
# `"0.5"`); anything else is double-quoted with `\`, `"` and `$` escaped so it
# can never re-parse as nushell syntax — `;`, `|`, `(` are excluded from the
# bare charset, so injection is structurally impossible.
def _emit-arg [arg: string] {
  if ($arg =~ '^[A-Za-z0-9_./:=,~@%+-]+$') {
    $arg
  } else {
    let esc = $arg | str replace --all '\' '\\' | str replace --all '"' '\"' | str replace --all '$' '\$'
    $'"($esc)"'
  }
}

# List every command the modules export, colon-style — `task --list`, nu-side.
# Private helpers (`def` without `export` still lands in scope via `source`)
# are included; the `_`-prefix convention is the only filter.
export def nutasks [] {
  scope commands
  | where type == "custom"
  | get name
  | where {|n| not ($n | str starts-with "_") }
  | each {|n| {task: ($n | str replace --all " " ":"), command: $n} }
  | sort-by task
}

# Invoke one task by colon name: `nu-task jobby:coverletter:render` runs
# `jobby coverletter render`. Command words must be [a-zA-Z0-9_-]+ — they are
# emitted bare so multi-word defs resolve by nushell's longest-prefix rule;
# forwarded arguments go through _emit-arg. A def whose last expression is an
# external propagates that exit code, so `nu-run x:y` returns the task's code.
export def nu-task [
  name: string      # colon-form task name, e.g. jobby:coverletter:render
  ...args: string   # arguments forwarded verbatim
] {
  let head = $name | split row ":" | where {|w| $w != "" }
  if ($head | is-empty) {
    error make {msg: "nu-task: empty task name — `nutasks` lists what exists"}
  }
  let bad = $head | where {|w| not ($w =~ '^[A-Za-z0-9_-]+$') }
  if ($bad | is-not-empty) {
    error make {msg: $"nu-task: bad task word `($bad | first)` — task words are letters, digits, _ and - only"}
  }
  let tail = if ($args | is-empty) {
    ""
  } else {
    " " + ($args | each {|a| _emit-arg $a } | str join " ")
  }
  let line = ($head | str join " ") + $tail
  let cfg_dir = $"($env.XDG_CONFIG_HOME? | default ($env.HOME + '/.config'))/nushell"
  ^nu --config $"($cfg_dir)/config.nu" --env-config $"($cfg_dir)/env.nu" -c $line
}
