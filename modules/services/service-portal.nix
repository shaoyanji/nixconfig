# The one registry for "what does this host serve, and where": the portal page,
# its cards and the tailnet mounts are all compiled from it, and the assertions
# below fail the build when a card and a service disagree.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.servicePortal;

  esc = s:
    builtins.replaceStrings
    ["&" "<" ">" "\"" "'"]
    ["&amp;" "&lt;" "&gt;" "&quot;" "&#39;"]
    (toString s);

  entryType = lib.types.submodule {
    options = {
      title = lib.mkOption {
        type = lib.types.str;
        description = "Card heading.";
      };
      description = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "One sentence about what the service is for.";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = lib.head cfg.groups;
        description = "Section heading; must be one of {option}`groups`.";
      };
      audience = lib.mkOption {
        type = lib.types.enum ["public" "lan" "tailnet"];
        default = "lan";
        description = ''
          Which page the card appears on. `tailnet` cards stay off the LAN page,
          because a LAN client cannot reach the tailnet name.
        '';
      };
      href = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Link target. Null means it is derived: from the exposure row's vhost,
          or from the mount's port and {option}`tailnetHost`.
        '';
      };
      scheme = lib.mkOption {
        type = lib.types.enum ["http" "https"];
        default = "http";
        description = "Scheme used when `href` is derived from an exposure vhost.";
      };
      badge = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Small footer text; derived from the address when null.";
      };
      vhost = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          The nginx vhost that serves this card. Checked against
          `services.nginx.virtualHosts`, so a card cannot outlive its vhost.
        '';
      };
      external = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Served by another daemon on this host, not by nginx — `gatus` is the
          case that needs it. Implies the card owns its own `href`.
        '';
      };
    };
  };

  mountType = lib.types.submodule {
    options = {
      port = lib.mkOption {
        type = lib.types.port;
        description = "Tailnet port; `tailscale serve` proxies a whole origin.";
      };
      upstream = lib.mkOption {
        type = lib.types.str;
        description = "Loopback URL tailscaled forwards to.";
      };
      title = lib.mkOption {
        type = lib.types.str;
        description = "Card heading for the auto-generated portal card.";
      };
      description = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "One sentence about the mounted service.";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "Tailnet services";
        description = "Section heading; must be one of {option}`groups`.";
      };
      requires = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = ''
          Units that must be up first. Each is checked against
          `systemd.services`, so a typo cannot leave a mount waiting on nothing.
        '';
      };
      hideCard = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Mount without a portal card (a machine-facing endpoint).";
      };
    };
  };

  exposure = config.profiles.serviceExposure.services or {};
  exposed = lib.filterAttrs (n: s: s.enable && s.proxy != null && !(builtins.elem n cfg.hiddenServices)) exposure;
  exposedKeys = builtins.attrNames exposed;

  # 1. Exposure rows. Missing metadata yields a visible placeholder here and a
  # failing assertion below, rather than a cryptic missing-attribute error.
  exposureCards =
    map (n: let
      s = exposed.${n};
      e = lib.attrByPath [n] null cfg.entries;
      scheme = e.scheme or "http";
    in {
      name = n;
      title =
        if e == null
        then "${n} (no portal entry)"
        else e.title;
      description =
        if e == null
        then "MISSING: services.servicePortal.entries.${n}"
        else e.description;
      group =
        if e == null
        then lib.head cfg.groups
        else e.group;
      audience = "lan";
      href =
        if e != null && e.href != null
        then e.href
        else "${scheme}://${s.proxy.name}";
      badge =
        if e != null && e.badge != null
        then e.badge
        else "${s.proxy.name} :${toString s.port}";
      vhost = s.proxy.name;
    })
    exposedKeys;

  # 2. Mounts. Metadata may be refined by an `entries.<name>`, but the mount is
  # the fact, so a mount can never be invisible in the registry.
  mountCards = map (n: let
    m = cfg.mounts.${n};
    e = lib.attrByPath [n] null cfg.entries;
  in {
    name = n;
    title =
      if e != null
      then e.title
      else m.title;
    description =
      if e != null
      then e.description
      else m.description;
    group =
      if e != null
      then e.group
      else m.group;
    audience = "tailnet";
    href =
      if e != null && e.href != null
      then e.href
      else "https://${cfg.tailnetHost}:${toString m.port}";
    badge =
      if e != null && e.badge != null
      then e.badge
      else "${cfg.tailnetHost}:${toString m.port}";
    vhost = null;
  }) (builtins.attrNames (lib.filterAttrs (_: m: !m.hideCard) cfg.mounts));

  # 3. Standalone cards: renames (`entries.paste` → `frieren.lan`) and things a
  # non-nginx daemon serves. A key that is neither an exposure row nor a mount,
  # and declares neither `vhost` nor `external`, is a card with no owner.
  knownKeys = exposedKeys ++ builtins.attrNames cfg.mounts;
  standaloneKeys =
    builtins.filter
    (n: !(builtins.elem n knownKeys) && (cfg.entries.${n}.vhost != null || cfg.entries.${n}.external))
    (builtins.attrNames cfg.entries);
  standaloneCards =
    map (n: let
      e = cfg.entries.${n};
    in {
      name = n;
      title = e.title;
      description = e.description;
      group = e.group;
      audience = e.audience;
      href =
        if e.href != null
        then e.href
        else if e.vhost != null
        then "http://${e.vhost}"
        else throw "services.servicePortal.entries.${n}: `external` needs an explicit `href`";
      badge =
        if e.badge != null
        then e.badge
        else if e.vhost != null
        then e.vhost
        else "";
      vhost = e.vhost;
    })
    standaloneKeys;

  allCards = exposureCards ++ mountCards ++ standaloneCards;
  visible = allCards;

  cardsFor = audiences:
    lib.concatMapStrings (g: let
      inGroup =
        lib.sort (a: b: a.title < b.title)
        (lib.filter (c: c.group == g && builtins.elem c.audience audiences) visible);
    in
      lib.optionalString (inGroup != []) ''
        <h2>${esc g}</h2>
        <div class="grid">
        ${lib.concatMapStrings (c: ''
            <a class="card" href="${esc c.href}">
              <div class="title">${esc c.title}</div>
              <div class="desc">${esc c.description}</div>
              ${lib.optionalString (c.badge != "") ''<div class="badge">${esc c.badge}</div>''}
            </a>
          '')
          inGroup}
        </div>
      '')
    cfg.groups;

  # The cards, as data, for the same reason `#fleet-docs-site` ships
  # `data/*.json`: a page is one renderer of a projection, and the next channel
  # (a TUI, a gatus probe, an agent) should read the projection, not scrape the
  # HTML. `services.servicePortal.json` is the host-independent copy.
  cardsJson = audiences:
    builtins.toJSON (map (c: {
      inherit (c) title description group audience href badge;
    }) (lib.filter (c: builtins.elem c.audience audiences) visible));

  page = audiences: let
    body = cardsFor audiences;
    html = pkgs.writeText "index.html" ''
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="robots" content="noindex">
          <title>${esc cfg.title}</title>
          <style>
            :root { --bg:#0d1117; --card:#161b22; --border:#30363d; --text:#c9d1d9; --accent:#58a6ff; }
            body { background:var(--bg); color:var(--text); margin:0; padding:2.5rem 1.5rem;
                   font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;
                   display:flex; flex-direction:column; align-items:center; }
            h1 { color:#fff; margin:0 0 .25rem; font-size:1.9rem; }
            p.sub { color:#8b949e; margin:0 0 2rem; }
            h2 { width:100%; max-width:60rem; font-size:1rem; color:#8b949e; font-weight:600;
                 border-bottom:1px solid var(--border); padding-bottom:.5rem; margin:1.5rem 0 .25rem; }
            .grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(260px,1fr));
                    gap:1rem; max-width:60rem; width:100%; }
            .card { display:flex; flex-direction:column; gap:.4rem; padding:1.1rem;
                    background:var(--card); border:1px solid var(--border); border-radius:8px;
                    text-decoration:none; color:inherit; }
            .card:hover { border-color:var(--accent); }
            .title { color:var(--accent); font-weight:600; }
            .desc { color:#8b949e; font-size:.875rem; line-height:1.4; }
            .badge { margin-top:auto; padding-top:.5rem; color:#58a6ff; font-size:.7rem; }
          </style>
        </head>
        <body>
          <h1>${esc cfg.title}</h1>
          <p class="sub">${esc cfg.subtitle}</p>
          ${body}
        </body>
      </html>
    '';
  in
    pkgs.runCommand "service-portal-page" {} ''
      mkdir -p $out/data
      cp ${html} $out/index.html
      cp ${pkgs.writeText "services.json" (cardsJson audiences)} $out/data/services.json
    '';

  mountPorts = map (m: m.port) (builtins.attrValues cfg.mounts);
  # Prefix test, not a regex: POSIX ERE rejected the bracket form of `[::1]`
  # at eval (measured on delphi, 2026-10-21), and a mount upstream is a literal
  # loopback URL in every case this registry will ever hold.
  isLoopback = u:
    lib.any (p: lib.hasPrefix p u) [
      "http://127.0.0.1"
      "https://127.0.0.1"
      "http://localhost"
      "https://localhost"
      "http://[::1]"
      "https://[::1]"
    ];
in {
  options.services.servicePortal = {
    enable = lib.mkEnableOption "the compiled service portal and its tailnet mounts";

    title = lib.mkOption {
      type = lib.types.str;
      description = "Page heading, usually the host name.";
    };

    subtitle = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "One line under the heading: role, address, platform.";
    };

    groups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["Services"];
      description = ''
        Section headings, in display order. Every card's `group` must be one of
        these — an undeclared group is a section nothing renders.
      '';
    };

    includeExposure = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Derive a card per exposed proxy from `profiles.serviceExposure`. Off for
        hosts whose exposure registry is empty.
      '';
    };

    hiddenServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Exposure keys deliberately kept off the page (an API with no UI). Naming
        one here is the explicit opt-out; silence is not.
      '';
    };

    tailnetHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "MagicDNS name used to link mounts, e.g. `host.tailnet.ts.net`.";
    };

    entries = lib.mkOption {
      type = lib.types.attrsOf entryType;
      default = {};
      description = "Card metadata, keyed by exposure key or mount name.";
    };

    mounts = lib.mkOption {
      type = lib.types.attrsOf mountType;
      default = {};
      description = ''
        `tailscale serve` https mounts, keyed by service name. The unit is
        generated as `tailscale-serve-<name>`.
      '';
    };

    pages = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      readOnly = true;
      description = "Generated pages: `public`, `lan` and `tailnet`.";
    };

    json = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      description = ''
        Every card as JSON — the projection a TUI or probe should consume rather
        than parsing the rendered page.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.servicePortal.pages = {
      public = page ["public"];
      lan = page ["lan" "public"];
      tailnet = page ["public" "lan" "tailnet"];
    };
    services.servicePortal.json = pkgs.writeText "service-portal.json" (cardsJson ["public" "lan" "tailnet"]);

    systemd.services = lib.mapAttrs' (n: m:
      lib.nameValuePair "tailscale-serve-${n}" {
        description = "Tailnet-only HTTPS front for ${m.title}";
        after = ["tailscaled.service"] ++ m.requires;
        wants = ["tailscaled.service"] ++ m.requires;
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${config.services.tailscale.package}/bin/tailscale serve --bg --https=${toString m.port} ${m.upstream}";
          ExecStop = "${config.services.tailscale.package}/bin/tailscale serve --https=${toString m.port} off";
        };
      })
    cfg.mounts;

    assertions = [
      {
        assertion = builtins.length mountPorts == builtins.length (lib.unique mountPorts);
        message = "services.servicePortal.mounts: two mounts share a tailnet port (${toString mountPorts}).";
      }
      {
        assertion = builtins.all (m: m.port != 80 && m.port != 443) (builtins.attrValues cfg.mounts);
        message = "services.servicePortal.mounts: 80 and 443 belong to nginx on this host; tailscaled cannot take them.";
      }
      {
        assertion = builtins.all (m: isLoopback m.upstream) (builtins.attrValues cfg.mounts);
        message = "services.servicePortal.mounts: an upstream must be loopback — a mount to 0.0.0.0 or a LAN address proxies past the tailnet fence.";
      }
      {
        assertion = builtins.all (m: builtins.all (u: builtins.hasAttr (lib.removeSuffix ".service" u) config.systemd.services) m.requires) (builtins.attrValues cfg.mounts);
        message = "services.servicePortal.mounts: `requires` names a unit that does not exist on this host.";
      }
      {
        assertion = cfg.mounts == {} || cfg.tailnetHost != null;
        message = "services.servicePortal: mounts need `tailnetHost`, or their cards have nowhere to point.";
      }
      {
        assertion = builtins.all (c: builtins.elem c.group cfg.groups) visible;
        message = "services.servicePortal: a card's `group` is not declared in `groups` — it would render in no section.";
      }
      {
        assertion = !cfg.includeExposure || builtins.all (n: cfg.entries ? ${n}) exposedKeys;
        message = "services.servicePortal: an exposed proxy has no portal entry (${toString (lib.subtractLists (builtins.attrNames cfg.entries) exposedKeys)}); add `entries.<key>` or name it in `hiddenServices`.";
      }
      {
        assertion = builtins.all (n: let
          e = cfg.entries.${n};
        in
          builtins.elem n (exposedKeys ++ builtins.attrNames cfg.mounts)
          || e.external
          || (e.vhost != null && config.services.nginx.virtualHosts ? ${e.vhost}))
        (builtins.attrNames cfg.entries);
        message = "services.servicePortal.entries: a card names neither an exposure row, a mount, a live nginx vhost, nor `external` — that is a link nobody serves.";
      }
    ];
  };
}
