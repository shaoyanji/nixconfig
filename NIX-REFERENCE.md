# Nix Reference for Nixconfig Refactoring

Quick reference for patterns used in this codebase.

## Attrset Merging

```nix
# // is SHALLOW, RIGHT-BIASED merge
{ a = 1; } // { b = 2; }           # => { a = 1; b = 2; }
{ a = 1; } // { a = 2; }           # => { a = 2; } (right wins)
{ a.x = 1; } // { a.y = 2; }       # => { a.y = 2; } (LOST a.x!)

# Use lib.recursiveUpdate for deep merge
lib.recursiveUpdate { a.x = 1; } { a.y = 2; }  # => { a.x = 1; a.y = 2; }
```

The `//` operator is used extensively for systemd serviceConfig merging:
```nix
serviceConfig = {
  User = "hermes";
  ExecStart = "...";
} // mountConfig  # mountConfig adds BindPaths, BindReadOnlyPaths, EnvironmentFile
  // lib.optionalAttrs (envFiles != []) { EnvironmentFile = envFiles; }
```

## Conditional Config

```nix
# lib.mkIf — only apply config when condition is true
config = lib.mkIf cfg.enable {
  services.foo.enable = true;
};

# lib.mkMerge — multiple conditional blocks
config = lib.mkMerge [
  (lib.mkIf cfg.enableA { services.a.enable = true; })
  (lib.mkIf cfg.enableB { services.b.enable = true; })
  { environment.systemPackages = [ pkgs.git ]; }  # always
];

# lib.optionalAttrs — conditional attrset (for // merging)
{} // lib.optionalAttrs (cfg.file != null) { configFile = cfg.file; }

# lib.optionals — conditional list items
services = [ pkgs.git ] ++ lib.optionals cfg.enableFoo [ pkgs.foo ];
```

## Option Priorities

```nix
# Priority order (highest wins):
#   mkForce (50) > regular (100) > mkDefault (1000) > mkOptionDefault (1500)
boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
networking.useDHCP = lib.mkDefault true;

# Custom priority
foo = lib.mkOverride 90 "value";
```

Key: When multiple modules define the same option, NixOS merges them
using the priority system. `mkForce` always wins, `mkDefault` loses
to any explicit definition.

## Module Structure

```nix
# A NixOS module is a function:
{ config, lib, pkgs, ... }: {
  options.services.foo = {
    enable = lib.mkEnableOption "Foo service";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };
  };

  config = lib.mkIf config.services.foo.enable {
    systemd.services.foo = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${pkgs.foo}/bin/foo";
    };
  };
}

# Parameterized module (profile pattern):
{ withBar ? false }: { config, lib, ... }: {
  imports = lib.optionals withBar [ ./bar.nix ];
  # ...
}
# Usage in host: (import ../../modules/profiles/ai-host.nix { withOpenclaw = true; })
```

## Common Types

```nix
lib.types.str              # string
lib.types.int              # integer
lib.types.bool             # true/false
lib.types.path             # nix path
lib.types.package          # derivation
lib.types.port             # 1-65535
lib.types.nullOr T         # null or T
lib.types.listOf T         # [ T ]
lib.types.attrsOf T        # { name = T; }
lib.types.attrs            # any attrset (avoid, prefer structured)
lib.types.enum [ "a" "b" ] # one of listed values
lib.types.lines            # strings merged by concatenating with \n
lib.types.submodule {      # nested option set
  options = { ... };
}
```

## Patterns in This Codebase

### ai-services-mounts helper

Every AI service (nullclaw, xs, openfang, pancakes-harness) uses this EXCEPT hermes:

```nix
# In the module:
let
  aiServicesMounts = import ../lib/ai-services-mounts.nix {inherit lib;};
in {
  options.aiServices.foo = {
    enable = lib.mkEnableOption "Foo";
    workspaceRoot = lib.mkOption { ... };
  } // aiServicesMounts.mkMountOptions "foo";   # adds contextRoot, stateDir, etc.

  config = lib.mkIf cfg.enable {
    systemd.services.foo.serviceConfig = {
      User = "foo";
      ExecStart = "...";
    } // aiServicesMounts.mkMountConfig cfg cfg.workspaceRoot   # adds BindPaths, etc.
      // lib.optionalAttrs (allEnvFiles != []) { EnvironmentFile = allEnvFiles; };
  };
}
```

The helper generates:
- `BindReadOnlyPaths`: context + shared defaults
- `BindPaths`: state directory
- `EnvironmentFile`: shared defaults + shared secrets

### Host-level hermes pattern (current, to be refactored)

Currently each host manually does what the helper does:
```nix
# Each host repeats this verbatim:
systemd.services.hermes-agent.serviceConfig = {
  BindReadOnlyPaths = [
    "/srv/data/ai-services/context:/var/lib/hermes/.ai-services/context"
    "-/srv/data/ai-services/defaults/shared.env:/var/lib/hermes/.ai-services/defaults/shared.env"
  ];
  BindPaths = [ "/srv/data/ai-services/state/hermes:/var/lib/hermes/.ai-services/state" ];
  EnvironmentFile = [ "-/srv/data/ai-services/defaults/shared.env" ]
    ++ config.services.hermes-agent.environmentFiles;
};
```

### lib.mkMerge for sops.secrets

```nix
sops.secrets = lib.mkMerge [
  (lib.mkIf enableNullClaw {
    nullclaw = { owner = "nullclaw"; group = "nullclaw"; mode = "0400"; };
  })
  (lib.mkIf enableHermes {
    hermes = { owner = "hermes"; group = "hermes"; mode = "0400"; };
  })
  {
    ai-services-shared-env = { owner = "root"; group = "root"; mode = "0444"; };
  }
];
```

## Gotchas

1. **`//` does NOT deep-merge nested attrs** — `//` on `{ a = { x = 1; }; } // { a = { y = 2; }; }`
   loses `a.x`. Use `lib.recursiveUpdate` or `lib.mkMerge` instead.

2. **`mkIf` returns a special type** — don't use `lib.mkIf` result as a regular attrset.
   It's only valid at `config =` level, not inside `//` chains.

3. **`lib.optionals` vs `lib.optional`** — `optionals` returns list, `optional` wraps single value.
   ```nix
   lib.optionals true [ 1 2 ]  # => [ 1 2 ]
   lib.optional true 1         # => [ 1 ]
   ```

4. **Module args must match** — `{ config, lib, pkgs, ... }:` the `...` is required if
   you don't consume all args (like `inputs`, `modulesPath`, etc.).

5. **Option types must match across definitions** — if one module defines an option as
   `types.str` and another as `types.int`, eval fails.
