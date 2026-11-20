# hosts/delphi/dsh-web.shadow.nix — the DeepSeek Harness web stack, retired
# from hosts/delphi/configuration.nix in the deep-slash (xs subject
# nixconfig:deep-slash-dsh-agy). The fleet's agent path is the headless
# cascade (`agy -p`, freebuff fallback); the browser harness at
# https://delphi.<tailnet>:8443 was an idle 24/7 surface on a 2-OCPU box.
#
# History worth keeping: the harness was pinned to the NATIVE lane because
# OCI A1 has no KVM — the sandbox guest runs under interpreted QEMU TCG, and
# an agent loop there stalls the CPU budget. That rationale is why reviving
# means restoring it here, not inside the microVM.
#
# Revive path: `services.dsh-web` stays imported on delphi, so uncommenting
# each block back into its home file is the whole move. The sops template
# `sops.templates."dsh-web.env"` was never removed — DEEPSEEK_API_KEY still
# renders to the same path, waiting for a reader.
_: {
  # --- was hosts/delphi/configuration.nix, services.dshWeb ------------------
  # services.dshWeb = {
  #   enable = true;
  #   user = user.name;
  #   port = dshPort;
  #   publicUrl = dshUrl;
  #   trustedHosts = ["${tailnetHost}:${toString servePort}"];
  #   environmentFile = config.sops.templates."dsh-web.env".path;
  # };
  #
  # let bindings removed with it (re-add beside tailnetHost):
  #   servePort = 8443;        # tailscale serve port for the harness
  #   dshPort = 3080;          # loopback bind
  #   dshUrl = "https://${tailnetHost}:${toString servePort}/";

  # --- was the `dsh` card in the tailscale-serve mounts ---------------------
  # dsh = {
  #   port = servePort;
  #   upstream = "http://127.0.0.1:${toString dshPort}";
  #   title = "DeepSeek Harness";
  #   description = "Agent loop, bash, model calls and workspaces, in the browser.";
  #   requires = ["dsh-web.service"];
  # };

  # --- was hosts/delphi/infra-stack.nix --------------------------------------
  # fleetSentinel.watchUnits entry:
  #   {unit = "dsh-web.service";}
  #
  # cgroup guards on the unit (2-OCPU box; the harness is the heavy thing):
  # systemd.services.dsh-web.serviceConfig = {
  #   CPUWeight = 200;
  #   IOWeight = 200;
  #   MemoryHigh = "1200M";
  #   MemoryMax = "1500M";
  # };
}
