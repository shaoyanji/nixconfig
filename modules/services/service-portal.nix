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

  telemetryPackage = pkgs.buildGoModule {
    pname = "service-portal-telemetry";
    version = "0.2.0";
    src = ./service-portal/telemetry;
    vendorHash = null;
    env.CGO_ENABLED = 0;
    meta = {
      description = "Loopback health and stats aggregator for service portal cards";
      mainProgram = "service-portal-telemetry";
    };
  };

  esc = s:
    builtins.replaceStrings
    ["&" "<" ">" "\"" "'"]
    ["&amp;" "&lt;" "&gt;" "&quot;" "&#39;"]
    (toString s);

  metricType = lib.types.submodule {
    options = {
      key = lib.mkOption {
        type = lib.types.str;
        description = "Stats JSON key copied onto the card.";
      };
      label = lib.mkOption {
        type = lib.types.str;
        description = "Short human-readable metric label.";
      };
    };
  };

  telemetryTargetType = lib.types.submodule {
    options = {
      baseUrl = lib.mkOption {
        type = lib.types.str;
        description = "Loopback base URL for the service being sampled.";
      };
      healthPath = lib.mkOption {
        type = lib.types.str;
        default = "/api/health";
        description = "Health endpoint path below `baseUrl`.";
      };
      statsPath = lib.mkOption {
        type = lib.types.str;
        default = "/api/stats";
        description = "Stats endpoint path below `baseUrl`.";
      };
      metrics = lib.mkOption {
        type = lib.types.listOf metricType;
        default = [];
        description = "Stats keys surfaced on the card, in display order.";
      };
    };
  };

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

  # The compiled card, as a value any second renderer can consume: a host
  # dossier, a TUI, a gatus probe. One registry, many renderers — never a second
  # declaration of the same service.
  cardType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Exposure key or mount name.";
      };
      title = lib.mkOption {type = lib.types.str;};
      description = lib.mkOption {type = lib.types.str;};
      group = lib.mkOption {type = lib.types.str;};
      audience = lib.mkOption {type = lib.types.enum ["public" "lan" "tailnet"];};
      href = lib.mkOption {type = lib.types.str;};
      badge = lib.mkOption {type = lib.types.str;};
      requires = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Units the card's mount waits on (mounts only).";
      };
      vhost = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      kind = lib.mkOption {
        type = lib.types.str;
        default = "link";
        description = "Where the card comes from: `nginx`, `mount` or `external`.";
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
      kind = "nginx";
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
    inherit (m) requires;
    vhost = null;
    kind = "mount";
  }) (cfg.mounts |> lib.filterAttrs (_: m: !m.hideCard) |> builtins.attrNames);

  # 3. Standalone cards: renames (`entries.paste` → `frieren.lan`) and things a
  # non-nginx daemon serves. A key that is neither an exposure row nor a mount,
  # and declares neither `vhost` nor `external`, is a card with no owner.
  knownKeys = exposedKeys ++ builtins.attrNames cfg.mounts;
  standaloneKeys =
    lib.filter
    (n: !(builtins.elem n knownKeys) && (cfg.entries.${n}.vhost != null || cfg.entries.${n}.external))
    (builtins.attrNames cfg.entries);
  standaloneCards =
    map (n: let
      e = cfg.entries.${n};
    in {
      name = n;
      inherit (e) title;
      inherit (e) description;
      inherit (e) group;
      inherit (e) audience;
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
      inherit (e) vhost;
      kind = "external";
    })
    standaloneKeys;

  allCards = exposureCards ++ mountCards ++ standaloneCards;
  visible = allCards;

  cardSearch = c: lib.toLower "${c.title} ${c.description} ${c.badge} ${c.group} ${c.name}";

  cardsFor = audiences:
    lib.concatMapStrings (g: let
      inGroup =
        lib.sortOn (x: x.title)
        (lib.filter (c: c.group == g && builtins.elem c.audience audiences) visible);
    in
      lib.optionalString (inGroup != []) ''
        <section class="group" data-group="${esc g}">
          <h2>${esc g} <span class="gn">${toString (builtins.length inGroup)}</span></h2>
          <div class="grid">
          ${lib.concatMapStrings (c: ''
            <a class="card" href="${esc c.href}" data-group="${esc c.group}"
               data-audience="${esc c.audience}" data-kind="${esc (c.kind or "link")}"
               data-service="${esc c.name}" data-search="${esc (cardSearch c)}">
              <div class="title">${esc c.title}</div>
              <div class="desc">${esc c.description}</div>
              <div class="foot">
                ${lib.optionalString (c.badge != "") ''<span class="badge">${esc c.badge}</span>''}
                <span class="kind">${esc (c.kind or "link")}</span>
              </div>
              <span class="live" data-live-for="${esc c.name}" hidden></span>
            </a>
          '')
          inGroup}
          </div>
        </section>
      '')
    cfg.groups;

  # The cards, as data, for the same reason `#fleet-docs-site` ships
  # `data/*.json`: a page is one renderer of a projection, and the next channel
  # (a TUI, a gatus probe, an agent) should read the projection, not scrape the
  # HTML. `services.servicePortal.json` is the host-independent copy.
  cardsJson = audiences:
    builtins.toJSON (map (c: {
      inherit (c) name title description group audience href badge;
      kind = c.kind or "link";
      requires = c.requires or [];
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
            .card .foot { margin-top:auto; display:flex; gap:.5rem; align-items:baseline; padding-top:.5rem; }
            .badge { color:#58a6ff; font-size:.7rem; }
            .kind { margin-left:auto; font-size:.6rem; letter-spacing:.06em; text-transform:uppercase;
                    color:#8b949e; border:1px solid var(--border); border-radius:4px; padding:.05rem .3rem; }
            .live { display:flex; flex-wrap:wrap; gap:.3rem .45rem; align-items:center; margin-top:.45rem;
                    padding-top:.45rem; border-top:1px solid var(--border); color:#8b949e;
                    font-size:.68rem; letter-spacing:.04em; }
            .live::before { content:""; width:.42rem; height:.42rem; border-radius:50%; background:#8b949e; }
            .live[data-status="online"]::before { background:#3fb950; }
            .live[data-status="online"] .live-status { color:#3fb950; }
            .live[data-status="degraded"]::before { background:#d29922; }
            .live[data-status="degraded"] .live-status { color:#d29922; }
            .live[data-status="offline"]::before { background:#f85149; }
            .live[data-status="offline"] .live-status { color:#f85149; }
            .live-status { font-weight:600; text-transform:uppercase; letter-spacing:.08em; }
            .live-metric { color:var(--text); }
            .live-latency, .live-uptime { border:1px solid var(--border); border-radius:999px; padding:.04rem .34rem; }
            .live-spark { color:var(--accent); font-size:.72rem; letter-spacing:.02em; }
            .card[data-live-status="degraded"] { border-color:#d29922; }
            .card[data-live-status="offline"] { border-color:#f85149; }
            .attention-banner { width:100%; max-width:60rem; margin:0 0 1rem; padding:.65rem .8rem;
                                border:1px solid #d29922; border-radius:6px; color:#d29922; background:rgba(210,153,34,.08); }
            .gn { font-weight:400; color:#484f58; }
            .toolbar { width:100%; max-width:60rem; display:flex; flex-wrap:wrap; gap:.5rem;
                       align-items:center; margin:0 0 1rem; }
            .toolbar input { flex:1 1 16rem; min-width:12rem; padding:.55rem .75rem; border-radius:6px;
                             border:1px solid var(--border); background:var(--card); color:var(--text);
                             font-size:.9rem; }
            .toolbar input:focus { outline:none; border-color:var(--accent); }
            .chips { display:flex; flex-wrap:wrap; gap:.35rem; }
            .chip { font:inherit; font-size:.75rem; padding:.3rem .6rem; border-radius:999px;
                    border:1px solid var(--border); background:transparent; color:#8b949e; cursor:pointer; }
            .chip[aria-pressed="true"] { border-color:var(--accent); color:var(--accent); }
            .meta { color:#8b949e; font-size:.75rem; margin-left:auto; }
            #none { color:#8b949e; margin:1.5rem 0 0; }
            footer { width:100%; max-width:60rem; color:#484f58; font-size:.7rem; margin-top:2rem; }
            [hidden] { display:none !important; }
          </style>
        </head>
        <body>
          <h1>${esc cfg.title}</h1>
          <p class="sub">${esc cfg.subtitle}</p>
          <div class="toolbar">
            <input id="search" type="search" placeholder="filter services — name, group, address"
                   autocomplete="off" spellcheck="false" aria-label="Filter services">
            <div class="chips" id="chips">
              <button class="chip" data-filter="all" aria-pressed="true">all</button>
              ${lib.concatMapStrings (g: ''<button class="chip" data-filter="${esc g}" aria-pressed="false">${esc g}</button>'')
        cfg.groups}
            </div>
            <button class="chip attention-chip" id="attention-chip" data-filter="attention" aria-pressed="false">attention</button>
            <span class="meta" id="count"></span>
          </div>
          <div class="attention-banner" id="attention-banner" hidden></div>
          ${body}
          <p id="none" hidden>nothing matches that filter</p>
          <footer><a href="data/services.json">data/services.json</a> · telemetry <a href="/api/telemetry/export?format=json">json</a> · <a href="/api/telemetry/export?format=csv">csv</a> · <a href="/api/telemetry/export?format=markdown">markdown</a> · one registry, every renderer</footer>
          <script>
            (function () {
              var search = document.getElementById("search");
              var count = document.getElementById("count");
              var none = document.getElementById("none");
              var cards = Array.prototype.slice.call(document.querySelectorAll(".card"));
              var groups = Array.prototype.slice.call(document.querySelectorAll("section.group"));
              var chips = Array.prototype.slice.call(document.querySelectorAll(".chip"));
              var active = "all";
              var attentionOnly = false;
              function apply() {
                var words = search.value.toLowerCase().split(/\s+/).filter(Boolean);
                var shown = 0;
                cards.forEach(function (card) {
                  var hay = card.getAttribute("data-search") || "";
                  var okGroup = active === "all" || card.getAttribute("data-group") === active;
                  var okWords = words.every(function (word) { return hay.indexOf(word) !== -1; });
                  var liveStatus = card.getAttribute("data-live-status") || "";
                  var okAttention = !attentionOnly || liveStatus === "degraded" || liveStatus === "offline";
                  var ok = okGroup && okWords && okAttention;
                  card.hidden = !ok;
                  if (ok) shown += 1;
                });
                groups.forEach(function (group) {
                  group.hidden = !group.querySelector(".card:not([hidden])");
                });
                count.textContent = shown === cards.length
                  ? cards.length + " services"
                  : shown + " of " + cards.length + " services";
                none.hidden = shown > 0;
              }
              chips.forEach(function (chip) {
                chip.addEventListener("click", function () {
                  var next = chip.getAttribute("data-filter");
                  if (next === "attention") {
                    attentionOnly = !attentionOnly;
                    chip.setAttribute("aria-pressed", String(attentionOnly));
                  } else {
                    active = next === active ? "all" : next;
                    chips.forEach(function (other) {
                      if (other.getAttribute("data-filter") === "attention") return;
                      other.setAttribute(
                        "aria-pressed",
                        String(other.getAttribute("data-filter") === active)
                      );
                    });
                  }
                  apply();
                });
              });
              search.addEventListener("input", apply);
              document.addEventListener("keydown", function (event) {
                if (event.key === "/" && document.activeElement !== search) {
                  event.preventDefault();
                  search.focus();
                  search.select();
                } else if (event.key === "Escape" && document.activeElement === search) {
                  search.value = "";
                  apply();
                  search.blur();
                }
              });
              apply();

              var liveSlots = Array.prototype.slice.call(document.querySelectorAll("[data-live-for]"));
              function metricText(value) {
                if (typeof value === "number") return Number.isInteger(value) ? String(value) : value.toFixed(1);
                if (typeof value === "boolean") return value ? "yes" : "no";
                return String(value == null ? "—" : value);
              }
              function sparkline(samples) {
                if (!samples || !samples.length) return "";
                var blocks = "▁▂▃▄▅▆▇█";
                var max = Math.max.apply(null, samples.concat([1]));
                return samples.map(function (latency) {
                  var index = Math.max(0, Math.min(blocks.length - 1, Math.round((latency / max) * (blocks.length - 1))));
                  return blocks.charAt(index);
                }).join("");
              }
              function renderLive(slot, state) {
                slot.textContent = "";
                slot.hidden = false;
                slot.setAttribute("data-telemetry-active", "1");
                slot.setAttribute("data-status", state.status || "unknown");
                var card = slot.closest(".card");
                if (card) card.setAttribute("data-live-status", state.status || "unknown");
                var status = document.createElement("span");
                status.className = "live-status";
                status.textContent = state.status || "unknown";
                slot.appendChild(status);
                if (typeof state.latency_ms === "number") {
                  var latency = document.createElement("span");
                  latency.className = "live-latency";
                  latency.textContent = state.latency_ms + " ms";
                  slot.appendChild(latency);
                }
                if (typeof state.uptime_percent === "number") {
                  var uptime = document.createElement("span");
                  uptime.className = "live-uptime";
                  uptime.textContent = state.uptime_percent.toFixed(1) + "% up";
                  slot.appendChild(uptime);
                }
                var spark = sparkline(state.latency_samples || []);
                if (spark) {
                  var line = document.createElement("span");
                  line.className = "live-spark";
                  line.textContent = spark;
                  slot.appendChild(line);
                }
                (state.metrics || []).slice(0, 3).forEach(function (metric) {
                  var item = document.createElement("span");
                  item.className = "live-metric";
                  item.textContent = metricText(metric.value) + " " + (metric.label || metric.key || "metric");
                  slot.appendChild(item);
                });
                slot.title = (state.error || "live service telemetry") +
                  " · p50 " + (state.p50_latency_ms || 0) + " ms" +
                  " · p95 " + (state.p95_latency_ms || 0) + " ms" +
                  (state.last_transition_at ? " · last transition " + state.last_transition_at : "");
              }
              function updateAttention(services) {
                var banner = document.getElementById("attention-banner");
                if (!banner) return;
                var names = Object.keys(services).filter(function (name) {
                  return services[name].status === "degraded" || services[name].status === "offline";
                });
                banner.hidden = names.length === 0;
                banner.textContent = names.length
                  ? names.length + " service" + (names.length === 1 ? "" : "s") + " need attention: " + names.join(", ")
                  : "";
              }
              function loadTelemetry() {
                if (!liveSlots.length || !window.fetch) return;
                fetch("/api/telemetry", {headers: {Accept: "application/json"}, cache: "no-store"})
                  .then(function (response) {
                    if (!response.ok) throw new Error("telemetry HTTP " + response.status);
                    return response.json();
                  })
                  .then(function (payload) {
                    var services = payload.services || {};
                    liveSlots.forEach(function (slot) {
                      var state = services[slot.getAttribute("data-live-for")];
                      if (!state) {
                        slot.hidden = true;
                        return;
                      }
                      renderLive(slot, state);
                    });
                    updateAttention(services);
                    apply();
                  })
                  .catch(function () {
                    liveSlots.forEach(function (slot) {
                      if (slot.getAttribute("data-telemetry-active") !== "1") return;
                      slot.textContent = "";
                      slot.hidden = false;
                      slot.setAttribute("data-status", "unknown");
                      var status = document.createElement("span");
                      status.className = "live-status";
                      status.textContent = "telemetry unavailable";
                      slot.appendChild(status);
                    });
                  });
              }
              loadTelemetry();
              setInterval(loadTelemetry, 15000);
            })();
          </script>
        </body>
      </html>
    '';
  in
    pkgs.runCommand "service-portal-page" {} ''
      mkdir -p $out/data
      cp ${html} $out/index.html
      cp ${pkgs.writeText "services.json" (cardsJson audiences)} $out/data/services.json
    '';

  # `tailscale serve` rewrites the whole config under an etag — one writer: docs/agent-turns.md
  serveLock = "/run/tailscale-serve.lock";
  serve = args: "${pkgs.util-linux}/bin/flock ${serveLock} ${config.services.tailscale.package}/bin/tailscale ${args}";

  mountPorts = map (m: m.port) (builtins.attrValues cfg.mounts);

  telemetryConfigFile = pkgs.writeText "service-portal-telemetry.json" (builtins.toJSON {
    targets = map (name: let
      target = cfg.telemetry.targets.${name};
    in {
      inherit name;
      base_url = target.baseUrl;
      health_path = target.healthPath;
      stats_path = target.statsPath;
      metrics =
        map (metric: {
          inherit (metric) key label;
        })
        target.metrics;
    }) (builtins.attrNames cfg.telemetry.targets);
  });

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

    telemetry = {
      enable = lib.mkEnableOption "loopback health and stats telemetry for portal cards";

      port = lib.mkOption {
        type = lib.types.port;
        default = 8105;
        description = "Loopback port for the telemetry aggregator. It is proxied by nginx; no tailnet mount or firewall port is opened.";
      };

      intervalSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 10;
        description = "Seconds between target polls.";
      };

      timeoutMilliseconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1500;
        description = "Per-request timeout for a target health or stats read.";
      };

      historySamples = lib.mkOption {
        type = lib.types.ints.positive;
        default = 144;
        description = "Per-target ring-buffer samples kept for latency and uptime calculations.";
      };

      alertWebhook = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional ntfy or generic webhook URL receiving debounced degradation and recovery alerts as JSON posts. Prefer SERVICE_PORTAL_ALERT_WEBHOOK in environmentFile when the URL contains a private topic or credential.";
      };

      environmentFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional systemd EnvironmentFile containing SERVICE_PORTAL_ALERT_WEBHOOK. Render it from sops; never put private topics or credentials in the Nix store.";
      };

      alertCooldownSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 900;
        description = "Minimum seconds between alert episodes for one target, suppressing flap spam.";
      };

      alertFailureThreshold = lib.mkOption {
        type = lib.types.ints.positive;
        default = 2;
        description = "Consecutive non-online samples required before a degradation alert is posted.";
      };

      alertRecovery = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Post a recovery alert when a target that raised an alert returns online.";
      };

      targets = lib.mkOption {
        type = lib.types.attrsOf telemetryTargetType;
        default = {};
        description = "Telemetry targets keyed by the service card/mount name.";
      };
    };

    cards = lib.mkOption {
      type = lib.types.listOf cardType;
      readOnly = true;
      description = ''
        Every card as a compiled value — the projection a second renderer reads
        instead of writing the list again. `delphi`'s dossier
        ({file}`lib/delphi-site.nix`) is the first consumer: one registry, two
        surfaces (a portfolio page and a tailnet console), no duplicated table.
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
    services.servicePortal.cards =
      map (c: {
        inherit (c) name title description group audience href badge vhost;
        kind = c.kind or "link";
        requires = c.requires or [];
      })
      visible;

    services.servicePortal.pages = {
      public = page ["public"];
      lan = page ["lan" "public"];
      tailnet = page ["public" "lan" "tailnet"];
    };
    services.servicePortal.json = pkgs.writeText "service-portal.json" (cardsJson ["public" "lan" "tailnet"]);

    systemd.services =
      lib.mapAttrs' (n: m:
        lib.nameValuePair "tailscale-serve-${n}" {
          description = "Tailnet-only HTTPS front for ${m.title}";
          after = ["tailscaled.service"] ++ m.requires;
          wants = ["tailscaled.service"] ++ m.requires;
          # `After=` is ordering, not readiness: at boot tailscaled is still
          # NoState, `tailscale serve` exits 1 exactly once, and the unit then
          # stays failed with no retry — every mount on delphi was down until a
          # manual restart (2026-10-26). Wait for BackendState=Running, and
          # re-assert the mount when tailscaled restarts, because serve
          # configuration is per-process state rather than a file.
          partOf = ["tailscaled.service"];
          wantedBy = ["multi-user.target"];
          unitConfig.StartLimitIntervalSec = 0;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            TimeoutStartSec = 150;
            Restart = "on-failure";
            RestartSec = 5;
            ExecStartPre = pkgs.writeShellScript "tailscale-serve-wait" ''
              set -euo pipefail
              state=NoState
              for _ in $(seq 1 60); do
                state=$(${config.services.tailscale.package}/bin/tailscale status --json 2>/dev/null |
                  ${pkgs.jq}/bin/jq -r '.BackendState // "NoState"' 2>/dev/null || echo NoState)
                if [ "$state" = Running ]; then
                  exit 0
                fi
                sleep 2
              done
              echo "tailscale serve: tailscaled not Running after 120s (last: $state)" >&2
              exit 1
            '';
            ExecStart = serve "serve --bg --https=${toString m.port} ${m.upstream}";
            ExecStop = serve "serve --https=${toString m.port} off";
          };
        })
      cfg.mounts
      // lib.optionalAttrs cfg.telemetry.enable {
        service-portal-telemetry = {
          description = "Loopback health and stats aggregator for service portal cards";
          wantedBy = ["multi-user.target"];
          unitConfig.X-Fleet-Role = "daemon";
          serviceConfig = {
            Type = "simple";
            DynamicUser = true;
            ExecStart = lib.escapeShellArgs [
              (lib.getExe telemetryPackage)
              "-addr"
              "127.0.0.1:${toString cfg.telemetry.port}"
              "-config"
              telemetryConfigFile
              "-interval"
              "${toString cfg.telemetry.intervalSeconds}s"
              "-timeout"
              "${toString cfg.telemetry.timeoutMilliseconds}ms"
              "-history"
              (toString cfg.telemetry.historySamples)
              "-alert-webhook"
              (
                if cfg.telemetry.alertWebhook == null
                then ""
                else cfg.telemetry.alertWebhook
              )
              "-alert-cooldown"
              "${toString cfg.telemetry.alertCooldownSeconds}s"
              "-alert-threshold"
              (toString cfg.telemetry.alertFailureThreshold)
              "-alert-recovery"
              (
                if cfg.telemetry.alertRecovery
                then "true"
                else "false"
              )
            ];
            EnvironmentFile = lib.optional (cfg.telemetry.environmentFile != null) cfg.telemetry.environmentFile;
            Restart = "always";
            RestartSec = 3;
            TimeoutStopSec = 10;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            NoNewPrivileges = true;
            RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
            MemoryMax = "128M";
          };
        };
      };

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
        assertion = !cfg.telemetry.enable || cfg.telemetry.targets != {};
        message = "services.servicePortal.telemetry: enable it only with at least one target.";
      }
      {
        assertion = builtins.all (target: isLoopback target.baseUrl) (builtins.attrValues cfg.telemetry.targets);
        message = "services.servicePortal.telemetry.targets: baseUrl must be loopback; the aggregator is not a LAN probe.";
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
      # The docs site cannot evaluate this host, so its clickable list lives in
      # `inventory.toml` (`network.links`). This is the direction that can drift
      # silently — a link to a port nothing serves — so it is the one asserted.
      # A host without the compiled inventory injected has no list to check.
      {
        assertion =
          !(config.fleet ? inventory)
          || (
            let
              h = config.fleet.inventory.hosts.${config.networking.hostName} or null;
              links =
                if h == null
                then []
                else (h.network.links or []);
              # An `external` card names its own href, so its port is the one in
              # that href rather than a mount's.
              externalPorts = builtins.concatMap (
                n: let
                  e = cfg.entries.${n};
                  m = builtins.match ".*:([0-9]+).*" (e.href or "");
                in
                  lib.optional e.external (
                    if m == null
                    then 0
                    else lib.toInt (lib.head m)
                  )
              ) (builtins.attrNames cfg.entries);
              served = mountPorts ++ map (s: s.port) (builtins.attrValues exposed) ++ externalPorts;
            in
              builtins.all (l: builtins.elem l.port served) links
          );
        message = ''
          inventory.toml network.links names a port this host does not serve: the docs page would link a dead endpoint. Declare a mount (or an exposure row) for it, or drop the link.'';
      }
      # The other direction: a card on this host's portal that the docs page
      # does not link is a service a reader still has to remember a port for.
      # `hideCard` is the explicit opt-out.
      {
        assertion =
          !(config.fleet ? inventory)
          || (
            let
              h = config.fleet.inventory.hosts.${config.networking.hostName} or null;
              linked =
                map (l: l.port)
                (
                  if h == null
                  then []
                  else (h.network.links or [])
                );
              shown =
                cfg.mounts
                |> lib.filterAttrs (_: m: !m.hideCard)
                |> builtins.attrValues
                |> builtins.catAttrs "port";
            in
              builtins.all (p: builtins.elem p linked) shown
          );
        message = ''
          a visible portal mount has no inventory.toml network.links row: the docs page would leave that service out, so a reader still has to remember its port. Add the link, or set `hideCard = true` on the mount.'';
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
