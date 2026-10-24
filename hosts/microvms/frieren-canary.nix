# Frieren Canary & Runtime Sandbox MicroVM (EXP-102)
#
# The guest skeleton — tap + static address, virtiofs store, shared ssh host key,
# predictable-name opt-out, the shutdown deadlock fix — lives in ./base.nix and is
# shared with every other guest. This file used to carry its own copy of all of it,
# which drifted: no `usePredictableInterfaceNames = false`, so udev renamed the NIC
# after networkd had matched on "e*", and the guest booted to a login prompt with no
# IPv4 address at all (`ssh frieren-canary` then timed out forever while the serial
# console looked healthy). What is left here is only what makes this guest a canary.
{
  config,
  lib,
  pkgs,
  ...
}: let
  user = import ../../modules/global/user.nix;
  # The dummy API is the canary's health surface: frieren's nginx proxies /canary/
  # here and scripts/task/vm-canary-test.sh asserts the JSON. One constant feeds the
  # listener AND the contract the test reads, so the port cannot drift between what
  # the guest serves and what the test probes.
  apiPort = 8080;
  subzeroclaw = pkgs.stdenv.mkDerivation {
    pname = "subzeroclaw";
    version = "0.1.0-unstable-2026-04";
    src = pkgs.fetchFromGitHub {
      owner = "genlayerlabs";
      repo = "subzeroclaw";
      rev = "6b6b5adcb4662e0202838b5549d254feca1fc2a3";
      hash = "sha256-JpQNFij1c1HwCMBdete5ydL5jHzitDwSG2muy/lJahk=";
    };
    buildPhase = ''
      $CC -Wall -Wextra -std=c11 -O2 -D_GNU_SOURCE -Isrc -o subzeroclaw src/subzeroclaw.c src/cJSON.c -lm
    '';
    installPhase = ''
      mkdir -p $out/bin $out/share/subzeroclaw
      cp subzeroclaw $out/bin/
      cp -r src Makefile README.md $out/share/subzeroclaw/
    '';
  };
in {
  imports = [
    (import ./base.nix {
      hostName = "frieren-canary";
      ipAddress = "192.168.83.10";
      tapId = "microvm1";
      mac = "02:00:00:00:00:01";
      hypervisor = "cloud-hypervisor";
      # Persistent identity for the guest's sshd, shared over virtiofs. The runner
      # creates it on first boot (scripts/task/run-canary.sh); base.nix then turns
      # key generation off, which is minutes of emulated CPU saved under TCG.
      sshHostKeys = "/var/lib/microvms/frieren-canary/ssh-host-keys";
      vcpu = 2;
      mem = 2048;
    })
  ];

  microvm.vsock.cid = 10;
  microvm.volumes = [
    {
      mountPoint = "/var";
      image = "var.img";
      size = 2048;
    }
  ];

  networking.nameservers = ["1.1.1.1" "8.8.8.8"];

  # base.nix authorises root for every guest; this one is a working sandbox, so it
  # also gives devji a login and passwordless sudo inside the throwaway VM.
  users.users.devji = {
    isNormalUser = true;
    home = "${user.home}";
    extraGroups = ["wheel"];
    # The fleet list plus the workstation key this guest's ssh alias uses. That key
    # is deliberately not in modules/config/authorized-keys.nix (fleet hosts trust
    # the SSH CA instead), so a guest that has no CA has to name it — otherwise
    # `ssh frieren-canary` is "Permission denied (publickey)" on a healthy guest.
    openssh.authorizedKeys.keys =
      config.ssh.authorizedKeys.keys
      ++ ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHnNR7isgO8VDY76XzwyH3mOg1/DQo8dZgqQOfziw0DQ devji@nixos"];
  };
  security.sudo.wheelNeedsPassword = false;
  # The fleet default is key-only root. Keep that here rather than inheriting
  # base.nix's password-less `PermitRootLogin = yes`: devji is the login.
  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";

  environment.systemPackages = with pkgs; [
    subzeroclaw
    gcc
    gnumake
    git
    curl
    jq
    sqlite
    procps
    htop
    python3
    file
    binutils
  ];

  # Seed SubZeroClaw agent configuration, skills, and self-modifying workspace
  system.activationScripts.subzeroclawSetup = {
    text = ''
          mkdir -p ${user.home}/.subzeroclaw/skills ${user.home}/.subzeroclaw/logs ${user.home}/workspace/subzeroclaw
          # SubZeroClaw config: written unconditionally (the canary is
          # ephemeral; the config is managed, not user-owned). The runner
          # (SubZeroClaw, in this microVM) talks only to the host
          # (192.168.83.1); frieren's nginx /eisen/ proxies to Eisen's
          # decision router (via Eisen's nginx /router/). The model is
          # policy:auto, so the router uses its Nix default (Kolibri).
          # api_key "none": the router forwards it to Jev; Jev rejects it
          # and the router falls back to Laya (fine for the hi test). For
          # real Jev decisions, set the real key via a secret (never here).
          cat << 'EOF' > ${user.home}/.subzeroclaw/config
      api_key  = "none"
      endpoint = "http://192.168.83.1/eisen/v1/chat/completions"
      request_extra = {"model":"policy:auto"}
      skills_dir = "${user.home}/.subzeroclaw/skills"
      log_dir    = "${user.home}/.subzeroclaw/logs"
      EOF

          if [ ! -f ${user.home}/.subzeroclaw/skills/sandbox.md ]; then
            cat << 'EOF' > ${user.home}/.subzeroclaw/skills/sandbox.md
      # Sandboxed Agent in NixOS MicroVM
      You are an autonomous agent running inside an isolated NixOS Cloud-Hypervisor MicroVM.
      Use the shell tool to run commands, inspect the environment, edit code, and compile software.
      Your workspace contains the source code of this agent harness at `${user.home}/workspace/subzeroclaw`.
      You are free to explore, create files, write scripts, or modify your own C source code.
      EOF
          fi

          if [ ! -f ${user.home}/workspace/subzeroclaw/Makefile ]; then
            cp -r ${subzeroclaw}/share/subzeroclaw/* ${user.home}/workspace/subzeroclaw/ 2>/dev/null || true
            chmod -R u+rw ${user.home}/workspace/subzeroclaw/ 2>/dev/null || true
          fi

          chown -R ${user.name}:users ${user.home}/.subzeroclaw ${user.home}/workspace 2>/dev/null || true
    '';
  };

  boot.kernelPackages = pkgs.linuxPackages_6_12;

  # Dummy HTTP Service for Model B Reverse Proxy Verification (EXP-102)
  systemd.services.canary-dummy-api = let
    serverScript = pkgs.writeText "dummy_server.py" ''
      import http.server, socketserver, json, time

      class Handler(http.server.SimpleHTTPRequestHandler):
          def do_GET(self):
              self.send_response(200)
              self.send_header("Content-Type", "application/json")
              self.end_headers()
              data = {
                  "status": "healthy",
                  "service": "canary-dummy-api",
                  "vm": "frieren-canary",
                  "timestamp": time.time(),
                  "uptime_seconds": time.monotonic()
              }
              self.wfile.write(json.dumps(data, indent=2).encode() + b"\n")

      with socketserver.TCPServer(("0.0.0.0", ${toString apiPort}), Handler) as httpd:
          httpd.serve_forever()
    '';
  in {
    # This canary is judged by whether it keeps answering, so it must come back
    # and must never be retired by systemd's start limit.
    unitConfig.X-Fleet-Role = "daemon";
    unitConfig.StartLimitIntervalSec = 0;
    # Read by scripts/task/vm-canary-test.sh: the port the guest is serving, as
    # declared, instead of a number copied into a test.
    unitConfig.X-Canary-Api-Port = toString apiPort;
    description = "Dummy HTTP Service for Model B Reverse Proxy Verification";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${serverScript}";
      Restart = "always";
      RestartSec = "2s";
      RestartSteps = 5;
      RestartMaxDelaySec = "300s";
      DynamicUser = true;
    };
  };

  # The contract this guest promises to the host proxy and to the test. An assertion
  # is the only place that can catch an address change that the proxy did not follow.
  assertions = [
    {
      assertion = config.networking.firewall.enable == false;
      message = "frieren-canary: the guest sits behind the host's NAT; a guest firewall only breaks ssh in ways that look like a network bug.";
    }
    {
      assertion = config.microvm.shares != [];
      message = "frieren-canary: the guest needs the virtiofs store share; without it nothing in /nix/store is readable.";
    }
  ];
}
