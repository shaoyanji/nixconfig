# ==============================================================================
# lib/aki-site.nix — Aki-Powered Nix-Native Static Documentation & Closure Explorer
# ==============================================================================
# An ultra-minimal hypermedia site (~270 B aki JS primitive) generated natively
# by Nix at build time. Emits index.html, aki.min.js, style.css, and static JSON
# slice transitions for instant, zero-daemon exploration of host inventories,
# closure attribution graphs, and debloat milestones.
# ==============================================================================
{
  pkgs,
  lib ? pkgs.lib,
  # Compiled registry from lib/inventory.nix (flake output `inventory`). Callers
  # in the flake pass it so this site cannot disagree with the hosts about a
  # host's kind/status/role; the TOML fallback exists only for a standalone
  # `nix-build lib/aki-site.nix` and is NOT defaults-normalised.
  inventory ? null,
}: let
  inventoryFile = ../inventory.toml;
  rawInventory =
    if builtins.pathExists inventoryFile
    then builtins.fromTOML (builtins.readFile inventoryFile)
    else {hosts = {};};
  inv =
    if inventory != null
    then inventory
    else rawInventory;

  skills = import ./skills.nix {inherit lib;};
  kg = import ./knowledge-graph.nix {
    inherit lib skills;
    inventory = inv;
  };

  # Aki hypermedia driver with delegated click listener for dynamic DOM mutations
  akiJs = ''
    (() => {
      function pollTelemetry() {
        fetch('data/live.json')
          .then(r => r.json())
          .then(d => {
            const el = document.getElementById('live-status-badge');
            if (el && d.uptime) {
              el.innerHTML = "🟢 " + d.hostname + ": " + d.uptime + " (Gen " + d.generation + ", load " + d.load + ")";
            }
          })
          .catch(() => {});
      }

      document.addEventListener('DOMContentLoaded', pollTelemetry);
      setInterval(pollTelemetry, 30000);

      document.addEventListener('click', (e) => {
        const el = e.target.closest('[url][fn="onclick"], [url]:not([fn])');
        if (!el) return;
        const url = el.getAttribute('url');
        if (!url) return;
        e.preventDefault();
        document.querySelectorAll('.nav-active').forEach(n => n.classList.remove('nav-active'));
        el.classList.add('nav-active');
        fetch(url)
          .then(r => r.json())
          .then(data => {
            Object.entries(data).forEach(([sel, props]) => {
              const target = document.querySelector(sel);
              if (target) Object.assign(target, props);
            });
            pollTelemetry();
          })
          .catch(err => console.error("Aki transition failed:", err));
      });
    })();
  '';

  styleCss = ''
    :root {
      --bg: #1a1b26;
      --card-bg: #24283b;
      --border: #414868;
      --text: #c0caf5;
      --text-muted: #7aa2f7;
      --heading: #7dcfff;
      --accent: #bb9af7;
      --green: #9ece6a;
      --red: #f7768e;
      --yellow: #e0af68;
      --code-bg: #16161e;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "JetBrains Mono", monospace;
      background-color: var(--bg);
      color: var(--text);
      line-height: 1.6;
      padding: 1.5rem;
    }
    header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding-bottom: 1rem;
      border-bottom: 1px solid var(--border);
      margin-bottom: 1.5rem;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 0.75rem;
    }
    .brand h1 {
      font-size: 1.35rem;
      color: var(--heading);
      letter-spacing: -0.02em;
    }
    .badge {
      display: inline-block;
      padding: 0.2rem 0.6rem;
      font-size: 0.75rem;
      font-weight: 600;
      border-radius: 9999px;
      text-transform: uppercase;
    }
    .badge-green { background: rgba(158, 206, 106, 0.2); color: var(--green); border: 1px solid var(--green); }
    .badge-yellow { background: rgba(224, 175, 104, 0.2); color: var(--yellow); border: 1px solid var(--yellow); }
    .badge-blue { background: rgba(122, 162, 247, 0.2); color: var(--text-muted); border: 1px solid var(--text-muted); }
    nav {
      display: flex;
      gap: 0.5rem;
      margin-bottom: 1.5rem;
      flex-wrap: wrap;
    }
    .tab-btn {
      background: var(--card-bg);
      color: var(--text);
      border: 1px solid var(--border);
      padding: 0.5rem 1rem;
      border-radius: 6px;
      cursor: pointer;
      font-size: 0.9rem;
      transition: all 0.15s ease;
    }
    .tab-btn:hover {
      border-color: var(--accent);
      color: #fff;
    }
    .tab-btn.nav-active {
      background: var(--accent);
      color: #1a1b26;
      font-weight: 600;
      border-color: var(--accent);
    }
    #breadcrumbs {
      font-size: 0.85rem;
      color: var(--text-muted);
      margin-bottom: 1rem;
      font-family: monospace;
    }
    .layout-grid {
      display: grid;
      grid-template-columns: 240px 1fr;
      gap: 1.5rem;
    }
    @media (max-width: 800px) {
      .layout-grid { grid-template-columns: 1fr; }
    }
    aside {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 1rem;
      height: fit-content;
    }
    aside h3 {
      font-size: 0.8rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: var(--text-muted);
      margin-bottom: 0.75rem;
    }
    .side-list {
      display: flex;
      flex-direction: column;
      gap: 0.4rem;
    }
    .side-btn {
      text-align: left;
      background: transparent;
      color: var(--text);
      border: 1px solid transparent;
      padding: 0.4rem 0.6rem;
      border-radius: 4px;
      cursor: pointer;
      font-size: 0.85rem;
      transition: all 0.15s ease;
      font-family: monospace;
    }
    .side-btn:hover {
      background: rgba(122, 162, 247, 0.1);
      border-color: var(--border);
    }
    .side-btn.nav-active {
      background: rgba(187, 154, 247, 0.2);
      border-color: var(--accent);
      color: var(--accent);
    }
    main {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 1.5rem;
      min-height: 480px;
    }
    .card-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: 1rem;
      margin: 1rem 0;
    }
    .card {
      background: var(--bg);
      border: 1px solid var(--border);
      border-radius: 6px;
      padding: 1rem;
    }
    .card h4 {
      color: var(--heading);
      margin-bottom: 0.5rem;
      font-size: 0.95rem;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 1rem 0;
      font-size: 0.88rem;
    }
    th, td {
      border: 1px solid var(--border);
      padding: 0.55rem 0.75rem;
      text-align: left;
    }
    th {
      background: var(--bg);
      color: var(--heading);
    }
    code, pre {
      font-family: "JetBrains Mono", monospace;
      background: var(--code-bg);
      padding: 0.2rem 0.4rem;
      border-radius: 4px;
      font-size: 0.85rem;
    }
    pre {
      padding: 0.75rem;
      overflow-x: auto;
      margin: 0.75rem 0;
      border: 1px solid var(--border);
    }
  '';

  # Asset fingerprinting hashes for immutable caching (Gap B)
  cssHash = builtins.substring 0 8 (builtins.hashString "sha256" styleCss);
  jsHash = builtins.substring 0 8 (builtins.hashString "sha256" akiJs);
  cssFileName = "style.${cssHash}.css";
  jsFileName = "aki.${jsHash}.min.js";

  # Top-level shell
  indexHtml = ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Fleet Control Plane & Closure Explorer</title>
      <link rel="stylesheet" href="${cssFileName}">
      <script src="${jsFileName}" defer></script>
    </head>
    <body>
      <header>
        <div class="brand">
          <h1>Fleet Control Plane</h1>
          <span id="live-status-badge" class="badge badge-green">🟢 frieren: Active Production</span>
        </div>
        <div>
          <span class="badge badge-blue">Aki Hypermedia</span>
        </div>
      </header>

      <nav>
        <button class="tab-btn nav-active" url="data/overview.json">Overview</button>
        <button class="tab-btn" url="data/inventory.json">Fleet Inventory</button>
        <button class="tab-btn" url="data/kg.json">Knowledge Graph</button>
        <button class="tab-btn" url="data/closure.json">Closure Graph</button>
        <button class="tab-btn" url="data/debloat.json">Debloat Playbook</button>
        <button class="tab-btn" url="data/services.json">Services & Ingress</button>
      </nav>

      <div id="breadcrumbs">fleet / overview</div>

      <div class="layout-grid">
        <aside>
          <div id="sidebar-title"><h3>Navigation</h3></div>
          <div id="sidebar-pane" class="side-list">
            <button class="side-btn nav-active" url="data/overview.json">Mainframe Summary</button>
            <button class="side-btn" url="data/inventory.json">Host Matrix</button>
            <button class="side-btn" url="data/kg.json">Knowledge Graph</button>
            <button class="side-btn" url="data/closure.json">Closure Rollup</button>
            <button class="side-btn" url="data/debloat.json">Debloat Status</button>
            <button class="side-btn" url="data/services.json">Port Map</button>
          </div>
        </aside>

        <main id="detail-pane">
          <h2>Fleet Mainframe & Storage Steward</h2>
          <p style="margin: 0.75rem 0; color: var(--text-muted);">
            Welcome to the Nix-native Fleet Control Plane and Static Closure Explorer.
            Driven entirely by pre-compiled hypermedia transitions with zero server daemons.
          </p>

          <div class="card-grid">
            <div class="card">
              <h4>System Generation</h4>
              <p>Generation 82 booted & nominal</p>
              <p><small style="color: var(--green);">Auto-upgrade active (04:00 daily)</small></p>
            </div>
            <div class="card">
              <h4>Closure Footprint</h4>
              <p>33.8 GiB total (3,946 store paths)</p>
              <p><small style="color: var(--text-muted);">Debloat roadmap targeting ~16-17 GiB floor</small></p>
            </div>
            <div class="card">
              <h4>Storage Health</h4>
              <p>1TB NVMe SSD + 2TB NAS HDD pool</p>
              <p><small style="color: var(--green);">0 Btrfs errors; SMART nominal (34°C)</small></p>
            </div>
            <div class="card">
              <h4>Mesh & Gateways</h4>
              <p>SimpleX Mesh & SMP Relay active</p>
              <p><small style="color: var(--heading);">Hermes gateway connected to Telegram</small></p>
            </div>
          </div>

          <h3 style="margin-top: 1.5rem; margin-bottom: 0.5rem; color: var(--heading);">Quick Navigation</h3>
          <p>Click any tab above to explore fleet hosts, dive into derivation closure trees, or view the debloat execution playbook.</p>
        </main>
      </div>
    </body>
    </html>
  '';

  # JSON Slices
  overviewJson = builtins.toJSON {
    "#breadcrumbs" = {textContent = "fleet / overview";};
    "#detail-pane" = {
      innerHTML = ''
        <h2>Fleet Mainframe & Storage Steward</h2>
        <p style="margin: 0.75rem 0; color: var(--text-muted);">
          Welcome to the Nix-native Fleet Control Plane and Static Closure Explorer.
          Driven entirely by pre-compiled hypermedia transitions with zero server daemons.
        </p>
        <div class="card-grid">
          <div class="card">
            <h4>System Generation</h4>
            <p>Generation 82 booted & nominal</p>
            <p><small style="color: var(--green);">Auto-upgrade active (04:00 daily)</small></p>
          </div>
          <div class="card">
            <h4>Closure Footprint</h4>
            <p>33.8 GiB total (3,946 store paths)</p>
            <p><small style="color: var(--text-muted);">Debloat roadmap targeting ~16-17 GiB floor</small></p>
          </div>
          <div class="card">
            <h4>Storage Health</h4>
            <p>1TB NVMe SSD + 2TB NAS HDD pool</p>
            <p><small style="color: var(--green);">0 Btrfs errors; SMART nominal (34°C)</small></p>
          </div>
          <div class="card">
            <h4>Mesh & Gateways</h4>
            <p>SimpleX Mesh & SMP Relay active</p>
            <p><small style="color: var(--heading);">Hermes gateway connected to Telegram</small></p>
          </div>
        </div>
      '';
    };
  };

  # Host list for sidebar
  hostKeys = builtins.attrNames (inv.hosts or {});
  activeHosts = builtins.filter (h: (inv.hosts.${h}.status or "") == "active") hostKeys;

  hostSidebarButtons = lib.concatStringsSep "\n" (
    map (
      h: ''<button class="side-btn" url="data/host-${h}.json">${h} (${inv.hosts.${h}.kind or "nix"})</button>''
    )
    activeHosts
  );

  inventoryJson = builtins.toJSON {
    "#breadcrumbs" = {textContent = "fleet / inventory";};
    "#sidebar-pane" = {innerHTML = hostSidebarButtons;};
    "#detail-pane" = {
      innerHTML = ''
        <h2>Fleet Device & Host Inventory</h2>
        <p style="margin: 0.75rem 0; color: var(--text-muted);">
          Canonical registry of active production devices, compute tiers, and roles.
        </p>
        <table>
          <thead>
            <tr>
              <th>Host</th>
              <th>Status</th>
              <th>Kind</th>
              <th>Arch</th>
              <th>Role</th>
            </tr>
          </thead>
          <tbody>
            ${lib.concatStringsSep "\n" (
          map (h: let
            info = inv.hosts.${h};
          in ''
            <tr>
              <td><strong><button class="side-btn" style="padding:0; border:none; color:var(--heading); cursor:pointer;" url="data/host-${h}.json">${h}</button></strong></td>
              <td><span class="badge ${
              if info.status == "active"
              then "badge-green"
              else "badge-yellow"
            }">${info.status}</span></td>
              <td>${info.kind or "nix"}</td>
              <td><code>${info.arch or "x86_64-linux"}</code></td>
              <td>${info.role or "N/A"}</td>
            </tr>
          '')
          activeHosts
        )}
          </tbody>
        </table>
      '';
    };
  };

  # Individual host pages
  mkHostJson = h: let
    info = inv.hosts.${h} or {};
    hw = info.hardware or {};
    net = info.network or {};
  in
    builtins.toJSON {
      "#breadcrumbs" = {textContent = "fleet / inventory / ${h}";};
      "#detail-pane" = {
        innerHTML = ''
          <h2>${h} — ${info.role or "Fleet Host"}</h2>
          <p style="margin: 0.5rem 0 1rem 0;"><span class="badge ${
            if (info.status or "") == "active"
            then "badge-green"
            else "badge-yellow"
          }">${info.status or "active"}</span> &bull; <code>${info.kind or "nixos"}</code> &bull; <code>${info.arch or "x86_64-linux"}</code></p>

          <div class="card-grid">
            <div class="card">
              <h4>Hardware Profile</h4>
              <p><strong>Model:</strong> ${hw.model or "Generic"}</p>
              <p><strong>CPU:</strong> ${hw.cpu or "x86_64"}</p>
              <p><strong>RAM:</strong> ${hw.ram or "N/A"}</p>
              <p><strong>GPU:</strong> ${hw.gpu or "Integrated"}</p>
            </div>
            <div class="card">
              <h4>Network & Access</h4>
              <p><strong>LAN IP:</strong> ${net.lan_ip or "DHCP"}</p>
              <p><strong>Tailscale:</strong> ${
            if net.tailscale or false
            then "Enabled"
            else "Disabled"
          }</p>
              <p><strong>SSH Alias:</strong> <code>${net.ssh_alias or h}</code></p>
            </div>
          </div>

          <h3 style="margin-top: 1.25rem; margin-bottom: 0.5rem; color: var(--heading);">Status Detail</h3>
          <p style="color: var(--text);">${info.status_detail or "Operational."}</p>
        '';
      };
    };

  # Closure attribution page
  closureJson = builtins.toJSON {
    "#breadcrumbs" = {textContent = "fleet / closure";};
    "#sidebar-pane" = {
      innerHTML = ''
        <button class="side-btn nav-active" url="data/closure.json">Attribution Rollup</button>
        <button class="side-btn" url="data/debloat.json">Debloat Playbook</button>
      '';
    };
    "#detail-pane" = {
      innerHTML = ''
        <h2>Closure Attribution & Subsystem Rollup</h2>
        <p style="margin: 0.75rem 0; color: var(--text-muted);">
          Measured on <strong>frieren</strong> generation 81/82 over 3,946 Nix store paths.
        </p>

        <div class="card-grid">
          <div class="card">
            <h4>Exclusive Bytes</h4>
            <p><strong>15.4 GiB (46%)</strong></p>
            <p><small style="color: var(--text-muted);">Reachable from exactly 1 owner; reclaimed when that owner goes.</small></p>
          </div>
          <div class="card">
            <h4>Shared Substrate</h4>
            <p><strong>16.2 GiB (48%)</strong></p>
            <p><small style="color: var(--text-muted);">Shared across 2+ owners (glibc, Python, LLVM, Mesa, GTK).</small></p>
          </div>
          <div class="card">
            <h4>Core Subsystem</h4>
            <p><strong>2.2 GiB (6%)</strong></p>
            <p><small style="color: var(--text-muted);">Kernel, initrd, firmware (809 MiB), fonts (262 MiB).</small></p>
          </div>
        </div>

        <h3 style="margin-top: 1.5rem; margin-bottom: 0.75rem; color: var(--heading);">Top Owners by Exclusive Bytes</h3>
        <table>
          <thead>
            <tr>
              <th>Owner Service / Target</th>
              <th>Exclusive Size</th>
              <th>Major Components</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><code>home-manager-devji</code></td>
              <td>9.4 GiB</td>
              <td>qmd (904 MiB), chromium (703 MiB), zen-browser (400 MiB)</td>
            </tr>
            <tr>
              <td><code>stirling-pdf.service</code></td>
              <td>1,008 MiB</td>
              <td>openjdk-25 (655 MiB), stirling-pdf (348 MiB)</td>
            </tr>
            <tr>
              <td><code>home-assistant.service</code></td>
              <td>929 MiB</td>
              <td>homeassistant core, frontend (270 MiB), botocore</td>
            </tr>
            <tr>
              <td><code>immich</code> (server + ML)</td>
              <td>790 MiB</td>
              <td>immich server, openvino (141 MiB), onnxruntime</td>
            </tr>
            <tr>
              <td><code>uptime-kuma.service</code></td>
              <td>380 MiB</td>
              <td>npm-deps, uptime-kuma</td>
            </tr>
            <tr>
              <td><code>readarr.service</code></td>
              <td>301 MiB</td>
              <td>readarr, dotnet-runtime</td>
            </tr>
            <tr>
              <td><code>plex.service</code></td>
              <td>213 MiB</td>
              <td>plexmediaserver</td>
            </tr>
          </tbody>
        </table>
      '';
    };
  };

  # Debloat playbook page
  debloatJson = builtins.toJSON {
    "#breadcrumbs" = {textContent = "fleet / debloat";};
    "#detail-pane" = {
      innerHTML = ''
        <h2>Closure Debloat Playbook (33.8 GiB &rarr; ~16-17 GiB)</h2>
        <p style="margin: 0.75rem 0; color: var(--text-muted);">
          Safe tier 1 configuration wins and structural debloat milestones.
        </p>

        <table>
          <thead>
            <tr>
              <th>Item</th>
              <th>Target</th>
              <th>Savings</th>
              <th>Status</th>
              <th>Action / Implementation</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><strong>T1-1</strong></td>
              <td>Chromium Deduplication</td>
              <td>~703 MiB</td>
              <td><span class="badge badge-green">Reclaimed</span></td>
              <td>Removed duplicate chromium from home packages in Gen 81.</td>
            </tr>
            <tr>
              <td><strong>T1-2</strong></td>
              <td>JetBrains Mono Font Pruning</td>
              <td>~262 MiB</td>
              <td><span class="badge badge-green">Applied</span></td>
              <td>Replaced 228 MiB nerd-fonts with upstream jetbrains-mono (~3 MiB).</td>
            </tr>
            <tr>
              <td><strong>T1-3</strong></td>
              <td>nixpkgs Store Decoupling</td>
              <td>~399 MiB</td>
              <td><span class="badge badge-green">Applied</span></td>
              <td>Decoupled <code>pkgs.path</code> in nix-path &rarr; <code>flake:nixpkgs</code>.</td>
            </tr>
            <tr>
              <td><strong>T1-6</strong></td>
              <td>CUPS & HPLIP Print Drivers</td>
              <td>~70 MiB</td>
              <td><span class="badge badge-green">Applied</span></td>
              <td>Disabled <code>services.printing</code> and drivers on headless NAS.</td>
            </tr>
            <tr>
              <td><strong>T1-4</strong></td>
              <td>MBROLA Speech Dispatcher</td>
              <td>~645 MiB</td>
              <td><span class="badge badge-yellow">Evaluating</span></td>
              <td>Requires package override for desktop browser TTS.</td>
            </tr>
            <tr>
              <td><strong>Sudo PATH</strong></td>
              <td>Non-Login /run/wrappers/bin</td>
              <td>Quality</td>
              <td><span class="badge badge-green">Resolved</span></td>
              <td>Exported in bashrcExtra and home.sessionPath for seamless sudo.</td>
            </tr>
          </tbody>
        </table>
      '';
    };
  };

  # Services & Ingress page
  servicesJson = builtins.toJSON {
    "#breadcrumbs" = {textContent = "fleet / services";};
    "#detail-pane" = {
      innerHTML = ''
        <h2>Active Ingress & Production Ports</h2>
        <p style="margin: 0.75rem 0; color: var(--text-muted);">
          Declarative service catalog hosted on frieren (<code>192.168.3.25</code>).
        </p>

        <table>
          <thead>
            <tr>
              <th>Port</th>
              <th>Protocol</th>
              <th>Service</th>
              <th>Scope & Function</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><code>80 / 443</code></td>
              <td>HTTP/HTTPS</td>
              <td>Nginx Reverse Proxy</td>
              <td>LAN & Tailnet ingress with SSL termination</td>
            </tr>
            <tr>
              <td><code>53 / 5335</code></td>
              <td>DNS</td>
              <td>Pi-hole FTL / Unbound</td>
              <td>Recursive DNS caching and LAN ad-blocking</td>
            </tr>
            <tr>
              <td><code>5223</code></td>
              <td>ED25519 TLS</td>
              <td>smp-server</td>
              <td>SimpleX Chat fleet messaging relay server</td>
            </tr>
            <tr>
              <td><code>5225</code></td>
              <td>WebSocket</td>
              <td>simplex-chat</td>
              <td>SimpleX Chat daemon (Hermes / devji / guckloch)</td>
            </tr>
            <tr>
              <td><code>6800 / 6801</code></td>
              <td>RPC / HTTP</td>
              <td>aria2 / AriaNg</td>
              <td>Declarative download daemon and web dashboard</td>
            </tr>
            <tr>
              <td><code>8088</code></td>
              <td>HTTP</td>
              <td>Kiwix Offline Wiki</td>
              <td>19.2M Wikipedia & 14.5k ArchWiki offline articles</td>
            </tr>
            <tr>
              <td><code>8123</code></td>
              <td>HTTP</td>
              <td>Home Assistant</td>
              <td>Smart home automation platform</td>
            </tr>
            <tr>
              <td><code>26000</code></td>
              <td>HTTP / PXE</td>
              <td>iVentoy</td>
              <td>Network PXE multi-ISO boot server</td>
            </tr>
          </tbody>
        </table>
      '';
    };
  };

  # Knowledge Graph slice (Gap D)
  kgJson = builtins.toJSON {
    "#breadcrumbs" = {textContent = "fleet / knowledge-graph";};
    "#sidebar-pane" = {
      innerHTML = ''
        <button class="side-btn nav-active" url="data/kg.json">Graph Overview</button>
        <button class="side-btn" url="data/inventory.json">Host Matrix</button>
        <button class="side-btn" url="data/closure.json">Closure Rollup</button>
      '';
    };
    "#detail-pane" = {
      innerHTML = ''
        <h2>Fleet Knowledge Graph & Architectural Projection</h2>
        <p style="margin: 0.75rem 0; color: var(--text-muted);">
          Deterministic structural view compiled directly from repository AST: hosts, skill manuals, and living docs.
        </p>

        <div class="card-grid">
          <div class="card">
            <h4>Entities (Nodes)</h4>
            <p><strong>${toString (builtins.length kg.graph.nodes)}</strong> total nodes</p>
            <p><small style="color: var(--text-muted);">${toString kg.graph.stats.hosts} hosts &bull; ${toString kg.graph.stats.skills} skills &bull; ${toString kg.graph.stats.docs} docs</small></p>
          </div>
          <div class="card">
            <h4>Mentions (Edges)</h4>
            <p><strong>${toString kg.graph.stats.edges}</strong> explicit connections</p>
            <p><small style="color: var(--green);">Zero embeddings &bull; Token-exact AST</small></p>
          </div>
          <div class="card">
            <h4>Query Interface</h4>
            <p><code>task ops:kg</code></p>
            <p><small style="color: var(--heading);">Instant sub-second projection</small></p>
          </div>
        </div>

        <h3 style="margin-top: 1.5rem; margin-bottom: 0.75rem; color: var(--heading);">Graph Projection Layers</h3>
        <table>
          <thead>
            <tr>
              <th>Layer</th>
              <th>Count</th>
              <th>Canonical Source</th>
              <th>Role in Fleet</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><strong>Hosts</strong></td>
              <td>${toString kg.graph.stats.hosts}</td>
              <td><code>inventory.toml</code></td>
              <td>Physical servers, workstations, VPS, and preserved states</td>
            </tr>
            <tr>
              <td><strong>Skills</strong></td>
              <td>${toString kg.graph.stats.skills}</td>
              <td><code>.agents/skills/*/SKILL.md</code></td>
              <td>Autonomous agent runbooks and operational skills</td>
            </tr>
            <tr>
              <td><strong>Living Documents</strong></td>
              <td>${toString kg.graph.stats.docs}</td>
              <td>Root markdown & <code>docs/*.md</code></td>
              <td>Fleet architecture, invariants, and system handoffs</td>
            </tr>
            <tr>
              <td><strong>Edges (Mentions)</strong></td>
              <td>${toString kg.graph.stats.edges}</td>
              <td>AST Token Parser</td>
              <td>Explicit cross-subsystem knowledge references</td>
            </tr>
          </tbody>
        </table>
      '';
    };
  };

  # Fallback live telemetry (Gap A)
  fallbackLiveJson = builtins.toJSON {
    hostname = "frieren";
    generation = "booted";
    uptime = "nominal";
    load = "0.0";
    memory = {
      used_mb = 0;
      total_mb = 0;
    };
    timestamp = "static-build";
  };

  # Individual JSON files for active hosts
  hostJsonFiles =
    map (h: {
      name = "data/host-${h}.json";
      file = pkgs.writeText "host-${h}.json" (mkHostJson h);
    })
    activeHosts;
in
  pkgs.runCommand "fleet-docs-site" {
    meta = {
      description = "Aki-powered static fleet documentation and closure explorer";
    };
  } ''
    mkdir -p $out/data
    cat <<'EOF' > $out/index.html
    ${indexHtml}
    EOF

    cat <<'EOF' > $out/${jsFileName}
    ${akiJs}
    EOF

    cat <<'EOF' > $out/${cssFileName}
    ${styleCss}
    EOF

    # Backward-compatible unhashed copies
    cp $out/${jsFileName} $out/aki.min.js
    cp $out/${cssFileName} $out/style.css

    cp ${pkgs.writeText "overview.json" overviewJson} $out/data/overview.json
    cp ${pkgs.writeText "inventory.json" inventoryJson} $out/data/inventory.json
    cp ${pkgs.writeText "kg.json" kgJson} $out/data/kg.json
    cp ${pkgs.writeText "closure.json" closureJson} $out/data/closure.json
    cp ${pkgs.writeText "debloat.json" debloatJson} $out/data/debloat.json
    cp ${pkgs.writeText "services.json" servicesJson} $out/data/services.json
    cp ${pkgs.writeText "live.json" fallbackLiveJson} $out/data/live.json

    ${lib.concatStringsSep "\n" (
      map (hj: "cp ${hj.file} $out/${hj.name}") hostJsonFiles
    )}

    # Pre-compress static assets for Nginx gzip_static (zero runtime CPU)
    gzip -9k $out/index.html $out/*.js $out/*.css $out/data/*.json
  ''
