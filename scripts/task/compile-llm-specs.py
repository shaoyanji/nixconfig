#!/usr/bin/env python3
"""
Compiles and templates markdown representations of system specs from inventory.toml
specifically formatted for LLM consumption, agent system prompts, and documentation.
"""

import argparse
import sys
import tomllib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
INVENTORY_FILE = REPO_ROOT / "inventory.toml"
AGENTS_MD = REPO_ROOT / "AGENTS.md"
DOCS_FLEET_MD = REPO_ROOT / "docs" / "fleet-inventory.md"
AGENTS_HOSTS_DIR = REPO_ROOT / ".agents" / "hosts"
AGENTS_FLEET_MD = REPO_ROOT / ".agents" / "fleet-matrix.md"
DEFAULT_TEMPLATE_PATH = REPO_ROOT / ".agents" / "templates" / "host-card.tmpl"

def load_inventory():
    with open(INVENTORY_FILE, "rb") as f:
        return tomllib.load(f)

def load_template(path=None):
    template_file = Path(path) if path else DEFAULT_TEMPLATE_PATH
    if template_file.exists():
        with open(template_file, "r", encoding="utf-8") as f:
            return f.read()
    return None

def render_host_card(h, info, template_str=None):
    status = info.get("status", "active")
    kind = info.get("kind", "nixos")
    arch = info.get("arch", "x86_64-linux")
    role = info.get("role", "")
    is_nix = info.get("is_nix", kind in ["nixos", "darwin", "home"])
    
    # Status badges
    if status == "active":
        if is_nix:
            status_badge = "🟢 **Active (Production Nix)**"
        else:
            status_badge = "🟢 **Active (Non-Nix Hosting)**"
    elif status == "wip":
        status_badge = "🟡 **WIP (Work in Progress - Not Live)**"
    else:
        status_badge = "⚪ **Preserved (Reference Pattern - Dormant)**"

    hw = info.get("hardware", {})
    net = info.get("network", {})
    persona = info.get("persona", {})

    extra_hw_lines = []
    if "display" in hw:
        extra_hw_lines.append(f"- **Display**: {hw['display']}")
    if "battery" in hw:
        extra_hw_lines.append(f"- **Power/Battery**: {hw['battery']}")
    if info.get("desktop_environment") and info.get("desktop_environment") != "headless":
        extra_hw_lines.append(f"- **Compositor/UI**: {info['desktop_environment']}")
    extra_hw_str = "\n".join(extra_hw_lines) + ("\n" if extra_hw_lines else "")

    extra_net_lines = []
    if "domain" in net:
        extra_net_lines.append(f"- **Domain**: {net['domain']}")
    if "gemini_url" in net:
        extra_net_lines.append(f"- **Gemini**: {net['gemini_url']}")
    if "gopher_url" in net:
        extra_net_lines.append(f"- **Gopher**: {net['gopher_url']}")
    extra_net_str = "\n".join(extra_net_lines) + ("\n" if extra_net_lines else "")

    # Allowed tasks and constraints
    tasks = "\n".join(f"- {t}" for t in persona.get("allowed_tasks", [])) or "- None defined"
    constraints = "\n".join(f"- ⚠ {c}" for c in persona.get("constraints", [])) or "- None defined"

    # Fallback to default template if none provided
    if not template_str:
        template_str = load_template()

    tailscale_info = "Enabled" if net.get("tailscale") else "None"
    if net.get("tailscale_hostname"):
        tailscale_info += f" (`{net['tailscale_hostname']}`)"

    context = {
        "hostname": h,
        "title": persona.get("title", f"{h} host"),
        "status_badge": status_badge,
        "kind": kind,
        "arch": arch,
        "is_nix_str": "Yes" if is_nix else "No (External Taskfile/SSH)",
        "role": role,
        "compute_tier": persona.get("compute_tier", "unspecified"),
        "model": hw.get("model", "Generic"),
        "cpu": hw.get("cpu", "x86_64"),
        "gpu": hw.get("gpu", "None"),
        "ram": hw.get("ram", "N/A"),
        "storage_layout": hw.get("storage_layout", hw.get("storage_type", "Standard")),
        "extra_hardware": extra_hw_str,
        "lan_ip": net.get("lan_ip", "None / Dynamic"),
        "tailscale_info": tailscale_info,
        "ssh_alias": net.get("ssh_alias", h),
        "extra_network": extra_net_str,
        "system_prompt_hint": persona.get("system_prompt_hint", ""),
        "allowed_tasks": tasks,
        "constraints": constraints,
    }

    try:
        return template_str.format(**context)
    except KeyError as e:
        # Fallback to safe substitution
        return f"# Error formatting template for {h}: missing key {e}"

def generate_fleet_matrix_markdown(data):
    hosts = data.get("hosts", {})
    doc = [
        "# Fleet LLM Context Matrix",
        "",
        "> Dense machine context matrix optimized for LLM token budgets and prompt injection.",
        "> Source of truth: [`inventory.toml`](file:///home/devji/Documents/nixconfig/inventory.toml).",
        "",
        "## Fleet Status Breakdown",
        "",
        "- **Active Production Nix Hosts (11)**: `frieren`, `poseidon`, `eisen`, `stark`, `fern`, `scratch`, `netbook`, `guckloch`, `kellerbench`, `kali`, `moto`",
        "- **Active External Non-Nix Hosts (3)**: `serv00`, `dragoncourt`, `envs`",
        "- **Work-in-Progress Hosts (1)**: `delphi` (OCI A1 bastion - NOT yet live)",
        "- **Preserved Architecture Patterns (16)**: `aceofspades`, `alarm`, `ancientace`, `applevalley`, `ares`, `aristotle`, `cassini`, `deckstation`, `demo`, `garnixMachine`, `minyx`, `mtfuji`, `penguin`, `schneeeule`, `sledgehammer`, `testvm`",
        "",
        "---",
        "",
        "## LLM Operational Constraints by Host Category",
        "",
        "### 1. Mainframe & Core Server (`frieren`)",
        "- **Sensitive Window**: 03:00-05:30 CET nightly backup and handoff window. Never schedule rebuilds here.",
        "- **Rebuild Rule**: At most ONE rebuild at a time; always commit and push to origin/main or autoUpgrade will revert next morning at 04:00.",
        "- **Declarative Services**: Kiwix (/var/lib/kiwix) is strictly declarative; never hand-edit.",
        "",
        "### 2. Workstations & Kiosks (`poseidon`, `eisen`, `stark`, `kellerbench`)",
        "- **GPU Drivers**: NVIDIA hosts (`poseidon`: RTX 3050 Ti Laptop open; `stark`: MX110 legacy_580 offload; `kellerbench`: GTX 750 Ti legacy_580). AMD hosts (`eisen`: RX 5700 Navi 10 Mesa).",
        "- **UI Priority**: Keep interactive desktop smooth on `poseidon` during heavy inference.",
        "",
        "### 3. Lightweight Terminals (`fern`, `scratch`, `netbook`)",
        "- **Thermal & CPU Caps**: Low-power dual-core CPUs. Offload compilation to `frieren` or remote builders.",
        "- **Scratch Disk Diet**: Shaky f2fs SSD; tmpfs logs and zram RAM-only swap.",
        "",
        "### 4. Non-Nix Shared Hosting (`serv00`, `dragoncourt`, `envs`)",
        "- **Strict Warning**: NON-NIX. NEVER run `nixos-rebuild`, `nix`, or NixOS commands.",
        "- **Serv00 Quota**: Strict 512 MB RAM limit. Violators killed by FreeBSD kernel. Manage via Devil CLI.",
        "",
        "### 5. Work in Progress (`delphi`)",
        "- **Status**: WIP / Not Live. Do not assume active production services until deployed.",
        "",
        "---",
        "",
        "## Quick Host Spec Reference",
        "",
        "| Host | Status | Nix? | Arch | Compute Tier | CPU / RAM / GPU | Primary Role |",
        "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |"
    ]

    for h, info in sorted(hosts.items()):
        status = info.get("status", "active")
        is_nix = info.get("is_nix", info.get("kind") in ["nixos", "darwin", "home"])
        nix_str = "Yes" if is_nix else "No (Ext)"
        arch = info.get("arch", "x86_64-linux")
        tier = info.get("persona", {}).get("compute_tier", "standard")
        hw = info.get("hardware", {})
        cpu = hw.get("cpu", "").split("(")[0].strip()
        ram = hw.get("ram", "").split("+")[0].strip()
        gpu = hw.get("gpu", "")
        hw_str = f"{cpu}, {ram}"
        if gpu and gpu not in ["None", "Integrated", "Integrated / Headless"]:
            hw_str += f", {gpu.split('(')[0].strip()}"
        role = info.get("role", "")
        
        status_icon = "🟢" if status == "active" else ("🟡" if status == "wip" else "⚪")
        doc.append(f"| {status_icon} **`{h}`** | `{status}` | {nix_str} | `{arch}` | `{tier}` | {hw_str} | {role} |")

    doc.append("")
    return "\n".join(doc)

def generate_agents_table(data):
    hosts = data.get("hosts", {})
    # 4 distinct groups: Active Nix (11), Active External Non-Nix (3), WIP (1), Preserved (16)
    active_nix = [h for h, v in hosts.items() if v.get("status") == "active" and v.get("is_nix", v.get("kind") in ["nixos", "darwin", "home"])]
    active_ext = [h for h, v in hosts.items() if v.get("status") == "active" and not v.get("is_nix", v.get("kind") in ["nixos", "darwin", "home"])]
    wip_hosts = [h for h, v in hosts.items() if v.get("status") == "wip"]
    preserved_hosts = [h for h, v in hosts.items() if v.get("status") == "preserved"]

    active_nix.sort()
    active_ext.sort()
    wip_hosts.sort()
    preserved_hosts.sort()

    lines = [
        "| Host | Status | Environment | Arch | Role & Hardware Overview | Module Path | Storage Layout |",
        "|------|--------|-------------|------|---------------------------|-------------|----------------|"
    ]

    def get_module_path(h, info):
        if h in ["serv00", "dragoncourt", "envs"]:
            return "taskfiles/" + h + ".yml"
        if h == "moto":
            return "taskfiles/moto.yml"
        if h in ["penguin", "alarm", "kali"]:
            return f"hosts/{h}.nix"
        if h == "garnixMachine":
            return "hosts/garnixMachine.nix"
        if h == "testvm":
            return "hosts/microvms/testvm.nix"
        return f"hosts/{h}/configuration.nix"

    def format_row(h, info, status_override=None):
        st = status_override or info.get("status", "active")
        is_nix = info.get("is_nix", info.get("kind") in ["nixos", "darwin", "home"])
        if st == "active":
            status_label = "**Active**"
            env_label = "`nixos`" if info.get("kind") == "nixos" else f"`{info.get('kind')}`"
            if not is_nix:
                env_label = "**Non-Nix** (External)"
        elif st == "wip":
            status_label = "*WIP (Not Live)*"
            env_label = f"`{info.get('kind')}`"
        else:
            status_label = "Preserved"
            env_label = f"`{info.get('kind')}`"

        arch = info.get("arch", "x86_64-linux")
        hw = info.get("hardware", {})
        cpu = hw.get("cpu", "")
        cpu_short = cpu.split("(")[0].strip() if "(" in cpu else cpu
        ram = hw.get("ram", "").split("+")[0].strip()
        gpu = hw.get("gpu", "")
        role = info.get("role", "")
        
        desc_parts = [role]
        hw_details = []
        if cpu_short:
            hw_details.append(cpu_short)
        if ram:
            hw_details.append(ram)
        if gpu and gpu not in ["Integrated", "Integrated / Headless", "None"]:
            gpu_short = gpu.split("(")[0].strip()
            hw_details.append(gpu_short)
        if hw_details:
            desc_parts.append(f"({', '.join(hw_details)})")
            
        desc = " ".join(desc_parts).replace("|", "\\|")
        mod_path = f"`{get_module_path(h, info)}`"
        storage = hw.get("storage_layout", hw.get("storage_type", "")).replace("|", "\\|")
        if len(storage) > 65:
            storage = storage[:62] + "..."
        return f"| `{h}` | {status_label} | {env_label} | `{arch}` | {desc} | {mod_path} | {storage} |"

    for h in active_nix:
        lines.append(format_row(h, hosts[h]))
    for h in active_ext:
        lines.append(format_row(h, hosts[h]))
    for h in wip_hosts:
        lines.append(format_row(h, hosts[h]))
    for h in preserved_hosts:
        lines.append(format_row(h, hosts[h]))

    return "\n".join(lines)

def update_agents_md(table_content):
    with open(AGENTS_MD, "r", encoding="utf-8") as f:
        content = f.read()

    start_marker = "### Complete Client OS Fleet Inventory (`flake/host-inventory.nix`)"
    end_marker = "### Module Layout"

    if start_marker not in content or end_marker not in content:
        print("ERROR: Markers not found in AGENTS.md", file=sys.stderr)
        return None

    prefix = content.split(start_marker)[0] + start_marker + "\n\n"
    suffix = "\n\n" + end_marker + content.split(end_marker)[1]

    note = "> **Source of truth**: [`inventory.toml`](file:///home/devji/Documents/nixconfig/inventory.toml) (31 total devices: 11 active Nix, 3 active non-Nix external, 1 WIP, 16 preserved).\n\n"
    return prefix + note + table_content + suffix

def generate_docs_fleet_markdown(data):
    meta = data.get("metadata", {})
    hosts = data.get("hosts", {})

    active_nix = {h: v for h, v in hosts.items() if v.get("status") == "active" and v.get("is_nix", v.get("kind") in ["nixos", "darwin", "home"])}
    active_ext = {h: v for h, v in hosts.items() if v.get("status") == "active" and not v.get("is_nix", v.get("kind") in ["nixos", "darwin", "home"])}
    wip_hosts = {h: v for h, v in hosts.items() if v.get("status") == "wip"}
    preserved_hosts = {h: v for h, v in hosts.items() if v.get("status") == "preserved"}

    doc = [
        "# Fleet Device & Host Inventory",
        "",
        "> Canonical device, hardware, operational status, and agent persona registry for `nixconfig`.",
        "> Source of truth: [`inventory.toml`](file:///home/devji/Documents/nixconfig/inventory.toml).",
        "",
        "## Fleet Overview Statistics",
        "",
        f"- **Total Registered Devices**: {meta.get('total_devices', len(hosts))}",
        f"- **Active Production Nix Devices**: {len(active_nix)}",
        f"- **Active External Non-Nix Hosting**: {len(active_ext)} (`serv00`, `dragoncourt`, `envs`)",
        f"- **Work-in-Progress (Not Live)**: {len(wip_hosts)} (`delphi`)",
        f"- **Preserved Architecture Archetypes**: {len(preserved_hosts)}",
        f"- **Canonical Repository**: [{meta.get('canonical_repo', '')}]({meta.get('canonical_repo', '')})",
        "",
        "---",
        "",
        "## 1. Active Production Nix Fleet (11 Devices)",
        "",
        "| Host | Category | Role | Hardware Summary | Desktop / Environment | Storage |",
        "| :--- | :--- | :--- | :--- | :--- | :--- |"
    ]

    for h, info in sorted(active_nix.items()):
        cat = info.get("category", "")
        role = info.get("role", "")
        hw = info.get("hardware", {})
        cpu = hw.get("cpu", "").split("(")[0].strip()
        ram = hw.get("ram", "").split("+")[0].strip()
        gpu = hw.get("gpu", "")
        hw_summary = f"{cpu}, {ram}"
        if gpu and gpu not in ["Integrated", "Integrated / Headless", "None"]:
            hw_summary += f", {gpu.split('(')[0].strip()}"
        de = info.get("desktop_environment", "headless")
        storage = hw.get("storage_type", "")
        doc.append(f"| **`{h}`** | `{cat}` | {role} | {hw_summary} | {de} | {storage} |")

    doc.extend([
        "",
        "---",
        "",
        "## 2. Active External Non-Nix Hosting (3 Devices)",
        "",
        "These environments are not managed by Nix/NixOS. Operations are executed via dedicated taskfiles and SSH commands.",
        "",
        "| Host | Environment / OS | Role | Management | Memory Limit / Quota | Primary Services |",
        "| :--- | :--- | :--- | :--- | :--- | :--- |"
    ])

    for h, info in sorted(active_ext.items()):
        arch = info.get("arch", "")
        role = info.get("role", "")
        hw = info.get("hardware", {})
        ram = hw.get("ram", "")
        taskfile = f"`taskfiles/{h}.yml`"
        services = ", ".join(info.get("software", {}).get("key_services", [])[:2])
        doc.append(f"| **`{h}`** | `{arch}` | {role} | {taskfile} | {ram} | {services} |")

    doc.extend([
        "",
        "---",
        "",
        "## 3. Work-in-Progress Outposts (1 Device)",
        "",
        "| Host | Status | Role | Cloud Shape / Hardware | Target Responsibilities |",
        "| :--- | :--- | :--- | :--- | :--- |"
    ])

    for h, info in sorted(wip_hosts.items()):
        role = info.get("role", "")
        hw = info.get("hardware", {})
        cpu = hw.get("cpu", "")
        ram = hw.get("ram", "")
        persona = info.get("persona", {})
        tasks = ", ".join(persona.get("allowed_tasks", [])[:3])
        doc.append(f"| **`{h}`** | *WIP (Not Live)* | {role} | {cpu}, {ram} | {tasks} |")

    doc.extend([
        "",
        "---",
        "",
        "## 4. Preserved Archetypes & Configurations (16 Devices)",
        "",
        "These hosts are not in active production but are preserved as architectural reference patterns and test configurations.",
        "",
        "| Host | Category | Architectural Role | Pattern Preserved / Reference Value |",
        "| :--- | :--- | :--- | :--- |"
    ])

    for h, info in sorted(preserved_hosts.items()):
        cat = info.get("category", "")
        role = info.get("role", "")
        detail = info.get("status_detail", "")
        doc.append(f"| **`{h}`** | `{cat}` | {role} | {detail} |")

    doc.extend([
        "",
        "---",
        "",
        "## 5. Device-Specific Agent Personas",
        "",
        "Each device defines an agent persona specifying its operational compute tier, allowed tasks, and strict constraints.",
        "",
        "| Host | Persona Title | Compute Tier | Allowed Workloads | Operational Constraints |",
        "| :--- | :--- | :--- | :--- | :--- |"
    ])

    for h, info in sorted(hosts.items()):
        persona = info.get("persona", {})
        title = persona.get("title", "")
        tier = persona.get("compute_tier", "")
        tasks = "<br>".join(f"• {t}" for t in persona.get("allowed_tasks", []))
        constraints = "<br>".join(f"⚠ {c}" for c in persona.get("constraints", []))
        st = info.get("status", "active")
        is_nix = info.get("is_nix", info.get("kind") in ["nixos", "darwin", "home"])
        if st == "active" and is_nix:
            status_flag = "🟢"
        elif st == "active" and not is_nix:
            status_flag = "🌐"
        elif st == "wip":
            status_flag = "🟡"
        else:
            status_flag = "⚪"
        doc.append(f"| {status_flag} **`{h}`** | {title} | `{tier}` | {tasks} | {constraints} |")

    doc.append("")
    return "\n".join(doc)

def generate_home_agents(host, output_path=None, custom_tmpl=None):
    data = load_inventory()
    hosts = data.get("hosts", {})
    if host not in hosts:
        print(f"ERROR: Host '{host}' not found in inventory.toml", file=sys.stderr)
        sys.exit(1)

    host_card = render_host_card(host, hosts[host], custom_tmpl).strip()

    # Look for persona AGENTS.md (host-specific first, fallback to hermes-persona)
    host_agents_file = REPO_ROOT / "modules" / "user" / "ai" / "personas" / host / "AGENTS.md"
    common_agents_file = REPO_ROOT / "modules" / "user" / "ai" / "hermes-persona" / "AGENTS.md"

    if host_agents_file.exists():
        persona_agents = host_agents_file.read_text(encoding="utf-8").strip()
    elif common_agents_file.exists():
        persona_agents = common_agents_file.read_text(encoding="utf-8").strip()
    else:
        persona_agents = ""

    compiled = f"{host_card}\n\n---\n\n{persona_agents}\n"

    if output_path:
        out = Path(output_path).expanduser().resolve()
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(compiled, encoding="utf-8")
        print(f"Generated home AGENTS.md for '{host}' -> {out}")
    return compiled

def main():
    parser = argparse.ArgumentParser(description="Compile and template system specs from inventory.toml for LLM and documentation consumption.")
    parser.add_argument("--host", help="Compile and print LLM markdown prompt card for a specific host to stdout")
    parser.add_argument("--template", help="Path to custom template file for host rendering")
    parser.add_argument("--compile-hosts", action="store_true", help="Compile all host prompt cards into .agents/hosts/<host>.md")
    parser.add_argument("--compile-fleet", action="store_true", help="Compile fleet context matrix into .agents/fleet-matrix.md")
    parser.add_argument("--sync-docs", action="store_true", help="Sync AGENTS.md, docs/fleet-inventory.md, and all .agents/ files")
    parser.add_argument("--check", action="store_true", help="Verify all documentation matches inventory.toml without modifying")
    parser.add_argument("--home-agents", help="Generate combined host fastfetch card + persona AGENTS.md for <HOST>")
    parser.add_argument("--output", help="Output destination file path (used with --home-agents or --host)")
    parser.add_argument("--sync-home", action="store_true", help="Sync combined host card + persona AGENTS.md directly to ~/AGENTS.md for current machine")
    args = parser.parse_args()

    data = load_inventory()
    hosts = data.get("hosts", {})

    custom_tmpl = load_template(args.template) if args.template else load_template()

    # Sync home AGENTS.md directly for current machine
    if args.sync_home:
        import socket
        current_host = socket.gethostname().split(".")[0]
        if current_host not in hosts and Path("/etc/hostname").exists():
            current_host = Path("/etc/hostname").read_text().strip().split(".")[0]
        if current_host not in hosts:
            current_host = "frieren"
        home_agents_dest = Path.home() / "AGENTS.md"
        generate_home_agents(current_host, output_path=home_agents_dest, custom_tmpl=custom_tmpl)

    # Combined host card + persona AGENTS.md query
    if args.home_agents:
        compiled = generate_home_agents(args.home_agents, output_path=args.output, custom_tmpl=custom_tmpl)
        if not args.output:
            print(compiled)
        return

    # Single host query
    if args.host:
        if args.host not in hosts:
            print(f"ERROR: Host '{args.host}' not found in inventory.toml", file=sys.stderr)
            sys.exit(1)
        card = render_host_card(args.host, hosts[args.host], custom_tmpl)
        if args.output:
            out = Path(args.output).expanduser().resolve()
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(card, encoding="utf-8")
            print(f"Wrote host card for '{args.host}' -> {out}")
        else:
            print(card)
        return

    # Check mode
    if args.check:
        drift = False
        new_agents = update_agents_md(generate_agents_table(data))
        with open(AGENTS_MD, "r", encoding="utf-8") as f:
            if f.read() != new_agents:
                print("AGENTS.md has drifted from inventory.toml")
                drift = True

        new_docs_fleet = generate_docs_fleet_markdown(data)
        if not DOCS_FLEET_MD.exists() or DOCS_FLEET_MD.read_text(encoding="utf-8") != new_docs_fleet:
            print("docs/fleet-inventory.md has drifted from inventory.toml")
            drift = True

        new_fleet_matrix = generate_fleet_matrix_markdown(data)
        if not AGENTS_FLEET_MD.exists() or AGENTS_FLEET_MD.read_text(encoding="utf-8") != new_fleet_matrix:
            print(".agents/fleet-matrix.md has drifted from inventory.toml")
            drift = True

        if drift:
            print("ERROR: Documentation or LLM spec cards have drifted. Run 'task dev:inventory:sync'.", file=sys.stderr)
            sys.exit(1)
        print("OK: All documentation and fleet matrix are fully in sync with inventory.toml.")
        return

    # Sync / Compile
    # 1. Update AGENTS.md
    agents_table = generate_agents_table(data)
    new_agents_md = update_agents_md(agents_table)
    if new_agents_md:
        with open(AGENTS_MD, "w", encoding="utf-8") as f:
            f.write(new_agents_md)
        print(f"Updated {AGENTS_MD}")

    # 2. Update docs/fleet-inventory.md
    docs_fleet_md = generate_docs_fleet_markdown(data)
    DOCS_FLEET_MD.parent.mkdir(parents=True, exist_ok=True)
    with open(DOCS_FLEET_MD, "w", encoding="utf-8") as f:
        f.write(docs_fleet_md)
    print(f"Updated {DOCS_FLEET_MD}")

    # 3. Update .agents/fleet-matrix.md
    fleet_matrix = generate_fleet_matrix_markdown(data)
    AGENTS_FLEET_MD.parent.mkdir(parents=True, exist_ok=True)
    with open(AGENTS_FLEET_MD, "w", encoding="utf-8") as f:
        f.write(fleet_matrix)
    print(f"Updated {AGENTS_FLEET_MD}")

    # 4. Optional: compile per-host markdown cards on demand
    if args.compile_hosts:
        AGENTS_HOSTS_DIR.mkdir(parents=True, exist_ok=True)
        for h, info in hosts.items():
            card = render_host_card(h, info, custom_tmpl)
            card_file = AGENTS_HOSTS_DIR / f"{h}.md"
            with open(card_file, "w", encoding="utf-8") as f:
                f.write(card)
        print(f"Compiled all {len(hosts)} host spec cards into {AGENTS_HOSTS_DIR}/*.md (gitignored)")

if __name__ == "__main__":
    main()
