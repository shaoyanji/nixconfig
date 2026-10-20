# Home AGENTS.md — one store path per host, no runtime re-parse.
{
  lib,
  inventory,
}: let
  root = ../.;

  badges = {
    active = "🟢 **Active**";
    wip = "🟡 **WIP (not live)**";
    preserved = "⚪ **Preserved (dormant)**";
  };

  preamble = builtins.readFile (root + "/docs/agent-context/HOME-PREAMBLE.md");

  bullets = xs: lib.concatMapStringsSep "\n" (x: "- ${x}") xs;
  line = label: v: lib.optionalString (v != "" && v != null) "- **${label}**: ${v}\n";

  personaFor = host: let
    hostFile = root + "/modules/user/ai/personas/${host}/AGENTS.md";
    commonFile = root + "/modules/user/ai/hermes-persona/AGENTS.md";
  in
    if builtins.pathExists hostFile
    then builtins.readFile hostFile
    else if builtins.pathExists commonFile
    then builtins.readFile commonFile
    else "";

  mkText = host: let
    h = inventory.hosts.${host} or (throw "home-agents: unknown host '${host}'");
    hw = h.hardware or {};
    net = h.network or {};
    p = h.persona or {};
    persona = personaFor host;

    hardware =
      line "Model" (hw.model or "")
      + line "CPU" (hw.cpu or "")
      + line "GPU" (hw.gpu or "")
      + line "RAM" (hw.ram or "")
      + line "Storage" (hw.storage_layout or "")
      + line "Display" (hw.display or "")
      + line "Power/Battery" (hw.battery or "")
      + line "Compositor/UI" (
        if (h.desktop_environment or "headless") == "headless"
        then ""
        else h.desktop_environment
      );

    network =
      line "LAN IP" (net.lan_ip or "")
      + line "Tailscale" (
        if (net.tailscale or false)
        then (net.tailscale_hostname or "enabled")
        else ""
      )
      + line "SSH alias" (net.ssh_alias or "")
      + line "Domain" (net.domain or "");

    tasks =
      if (p.allowed_tasks or []) == []
      then "- None defined"
      else bullets p.allowed_tasks;

    constraints =
      if (p.constraints or []) == []
      then ""
      else "\n## Constraints\n\n" + bullets p.constraints + "\n";

    notes =
      if (h.notes or []) == []
      then ""
      else "\n## Notes\n\n" + bullets h.notes + "\n";
  in ''
    ${preamble}

    ---

    # Host System Context: ${host}

    > **Target Identity**: ${p.title or ""}
    > **Status**: ${badges.${h.status or "preserved"} or (h.status or "unknown")} | **Kind**: `${h.kind or "unknown"}` | **Arch**: `${h.arch or "unknown"}`
    > **Role**: ${h.role or ""}
    > **Compute Tier**: `${p.compute_tier or "unclassified"}`

    ## Hardware Profile & Ground Truth
    ${hardware}
    ## Network & Access
    ${network}
    ## System Directive
    > ${p.system_prompt_hint or "Operate this host according to AGENTS.md."}

    ## Allowed Workloads
    ${tasks}
    ${constraints}${notes}
    ---

    ${persona}
  '';
in {
  inherit mkText;
}
