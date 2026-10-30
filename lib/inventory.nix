# Fleet inventory: schema + compiler for `inventory.toml`.
{
  lib,
  src ? ../inventory.toml,
}: let
  inherit (lib) mkOption types;

  raw = builtins.fromTOML (builtins.readFile src);

  # Shorthands: every field is optional with an empty default, so a host only
  # states what it knows and the compiled record is uniform.
  str = default:
    mkOption {
      type = types.str;
      inherit default;
    };
  bool = default:
    mkOption {
      type = types.bool;
      inherit default;
    };
  strs = mkOption {
    type = types.listOf types.str;
    default = [];
  };

  hardwareModule = {
    options = {
      model = str "";
      cpu = str "";
      gpu = str "";
      ram = str "";
      display = str "";
      battery = str "";
      storage_type = str "";
      storage_layout = str "";
    };
  };

  networkModule = {
    options = {
      lan_ip = str "";
      # The NIC's address, consumed by `infra:wol:*`. Declared HERE first: the
      # schema is what makes a field real. `types.submodule` has no freeform
      # passthrough, so a `mac =` row in the TOML without this option is an eval
      # error ("The option `hosts.<h>.network.mac' does not exist") — the TOML is
      # the reflected data, this file is the truth about its shape.
      mac = str "";
      tailscale_ip = str "";
      domain = str "";
      ssh_alias = str "";
      tailscale_hostname = str "";
      gemini_url = str "";
      gopher_url = str "";
      tailscale = bool false;
    };
  };

  softwareModule = {
    options = {
      module_chain = str "";
      impermanence = bool false;
      key_services = strs;
      traits = strs;
    };
  };

  personaModule = {
    options = {
      title = str "";
      system_prompt_hint = str "";
      compute_tier = str "";
      allowed_tasks = strs;
      constraints = strs;
    };
  };

  hostModule = {name, ...}: {
    options = {
      # Defaults to the attribute key, so `[hosts.fern]` needs no `hostname`.
      hostname = str name;
      kind = mkOption {type = types.enum ["nixos" "darwin" "home" "external"];};
      arch = mkOption {type = types.str;};
      status = mkOption {type = types.enum ["active" "preserved" "wip"];};
      status_detail = str "";
      role = str "";
      category = str "";
      desktop_environment = str "";
      users = strs;
      # "Produced by this flake." Implied false for `kind = "external"`; set
      # false explicitly for a real host deliberately outside the flake
      # (netbook: pinned 25.11 channel, applied by remote fleet ops). This
      # replaces the prose note that used to carry the same fact.
      flake = bool true;
      managed = bool false;
      # Host (by hostname) allowed to build and deploy this one. Declared because
      # a cross-architecture host has exactly one builder in this fleet, and the
      # keeper refuses to run where it is not the declared one.
      builder = str "";
      ci = bool true;
      # Declared only where it adds information; `derived.isNix` is the truth
      # and any declared value must AGREE with it or it is reported in `issues`.
      is_nix = mkOption {
        type = types.nullOr types.bool;
        default = null;
      };
      system_type = str "";
      # Free-form operational commentary. This is the home for what used to be
      # long Nix comments: it is compiled, searchable and shipped in the feed.
      notes = strs;
      hardware = mkOption {
        type = types.submodule hardwareModule;
        default = {};
      };
      network = mkOption {
        type = types.submodule networkModule;
        default = {};
      };
      software = mkOption {
        type = types.submodule softwareModule;
        default = {};
      };
      persona = mkOption {
        type = types.submodule personaModule;
        default = {};
      };
    };
  };

  # A repository that belongs to the same person as the fleet but not to this
  # tree: a site or profile whose code, CI and authoring method live in its own
  # repo. Registered so "what else is ours" has one answer (`nix eval
  # .#inventory.repos`) instead of a prose list that goes stale — and NOT a
  # device: nothing here enters `derived`, the fleet catalog's host tables, or
  # any deploy/warm path.
  repoModule = {
    options = {
      url = str "";
      default_branch = str "";
      status = mkOption {type = types.enum ["active" "legacy" "archived"];};
      # Where a push ends up, and the workflow that does it ("" = no CI).
      deploy = str "";
      ci = str "";
      # How content is written, which is the part that differs per repo.
      authoring = str "";
      # A checkout held on the fleet, when one exists; "" when the repo is only
      # cloned on demand.
      local_path = str "";
      notes = strs;
    };
  };

  metadataModule = {
    options = {
      title = str "";
      description = str "";
      version = str "";
      canonical_repo = str "";
      # Declared copies. These are derived facts; `issues` reports any host
      # addition that was not reflected here, so the file cannot drift.
      total_devices = mkOption {
        type = types.int;
        default = 0;
      };
      active_nix_devices = mkOption {
        type = types.int;
        default = 0;
      };
      active_external_devices = mkOption {
        type = types.int;
        default = 0;
      };
      wip_devices = mkOption {
        type = types.int;
        default = 0;
      };
      preserved_devices = mkOption {
        type = types.int;
        default = 0;
      };
    };
  };

  # Type errors (unknown keys, wrong types) surface here, when `config` is
  # forced — which every consumer does.
  evaluated = lib.evalModules {
    modules = [
      {
        options = {
          metadata = mkOption {type = types.submodule metadataModule;};
          hosts = mkOption {type = types.attrsOf (types.submodule hostModule);};
          repos = mkOption {
            type = types.attrsOf (types.submodule repoModule);
            default = {};
          };
        };
        config = {
          metadata = raw.metadata or {};
          hosts = raw.hosts or {};
          repos = raw.repos or {};
        };
      }
    ];
  };

  hosts = evaluated.config.hosts;
  metadata = evaluated.config.metadata;
  repos = evaluated.config.repos;

  # The cache decision, compiled from the same `category` the hosts carry. It is
  # exposed here so that `global.nix`, `activate-host.sh` and `warm-host.sh` read
  # ONE answer instead of each re-deriving it — the bug that gated a cloud host on
  # a LAN cache it cannot reach.
  cachePolicy = import ./cache-policy.nix {inherit lib;};
  names = lib.attrNames hosts;

  isNixHost = host: host.kind != "external";

  nixHosts = lib.filterAttrs (_: isNixHost) hosts;
  externalHosts = lib.filterAttrs (_: host: !isNixHost host) hosts;

  count = pred: lib.length (lib.filter pred (lib.attrValues hosts));

  # The single source of truth for fleet size and composition.
  derived = {
    total = lib.length names;
    active = count (h: h.status == "active");
    activeNix = count (h: h.status == "active" && isNixHost h);
    activeExternal = count (h: h.status == "active" && !isNixHost h);
    wip = count (h: h.status == "wip");
    preserved = count (h: h.status == "preserved");
    nix = lib.length (lib.attrNames nixHosts);
    external = lib.length (lib.attrNames externalHosts);
  };

  declaredCounts = {
    total_devices = derived.total;
    active_nix_devices = derived.activeNix;
    active_external_devices = derived.activeExternal;
    wip_devices = derived.wip;
    preserved_devices = derived.preserved;
  };

  # Every way inventory.toml can disagree with itself. Empty = clean; check
  # `checks.<system>.inventory-schema` turns a non-empty list into a failure.
  # `flatten`, not `concatLists`: each `mapAttrsToList` yields a list OF lists of
  # `lib.optional` results, so a single `concatLists` would leave `[ ]` elements
  # behind and `ok` would be false with no real problem.
  issues = lib.flatten [
    (lib.mapAttrsToList
      (key: expected:
        lib.optional (metadata.${key} != expected)
        "metadata.${key} declares ${toString metadata.${key}} but inventory.toml now derives ${toString expected}; run `task dev:inventory:counts`")
      declaredCounts)
    (lib.mapAttrsToList
      (name: host:
        lib.optional
        (host.is_nix != null && host.is_nix != isNixHost host)
        "hosts.${name}: is_nix = ${lib.boolToString host.is_nix} contradicts kind = ${host.kind}")
      hosts)
    (lib.mapAttrsToList
      (name: host:
        lib.optional
        (host.system_type == "non-nix" && isNixHost host)
        "hosts.${name}: system_type = non-nix contradicts kind = ${host.kind}")
      hosts)
    (lib.mapAttrsToList
      (name: host:
        lib.optional
        (host.status == "active" && host.kind == "external" && host.managed)
        "hosts.${name}: a non-Nix device cannot be `managed` (managed = fleet deploy/warm rotation)")
      hosts)
  ];

  compiled = {
    metadata = metadata // declaredCounts;
    inherit hosts derived repos;
  };
in
  compiled
  // {
    inherit
      names
      nixHosts
      externalHosts
      repos
      derived
      issues
      ;
    # True when the file is internally consistent. Checks assert this.
    ok = issues == [];
    # Every Nix-kind host the flake is expected to build. The coverage check
    # compares this against the flake's own output set.
    flakeHosts = lib.filterAttrs (_: h: isNixHost h && h.flake) hosts;
    # Per-host lookup that fails loudly rather than returning null.
    host = name: hosts.${name} or (throw "inventory: no such host '${name}' in ${toString src}");
    # `.#inventory.cache.<host>`: substituters, trusted keys, where it is warmed
    # and which stores a deploy may pull from. Scripts read this instead of
    # branching on `category` themselves.
    cache = cachePolicy.forHosts hosts;
    # The compiled registry as typed data. `artifacts.inventory-json` serializes
    # it at the edge; this file never carries a JSON string, so a consumer that
    # wants JSON asks for it and the format check happens where the bytes are made.
    inherit compiled;
  }
