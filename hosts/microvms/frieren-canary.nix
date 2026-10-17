# Frieren Canary & Runtime Sandbox MicroVM (EXP-102)
#
# Provides an ephemeral, fast-boot (< 500ms) NixOS testing environment:
# - Shares host /nix/store via virtiofs (zero store copying / duplication).
# - Ephemeral writable overlay for builds and system activations.
# - Fixed persistent SSH host keys mounted from /var/lib/microvms/frieren-canary/ssh-host-keys
#   to ensure the host never experiences known_hosts collisions across teardowns.
# - Local NetworkManager bridge networking (microbr: 192.168.83.1 -> 192.168.83.10).
# - Hypervisor: cloud-hypervisor over KVM.
{
  config,
  pkgs,
  ...
}: let
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
    ../../modules/config/authorized-keys.nix
  ];

  microvm = {
    hypervisor = "cloud-hypervisor";
    vcpu = 2;
    mem = 2048;
    vsock.cid = 10;

    interfaces = [
      {
        type = "tap";
        id = "microvm1";
        mac = "02:00:00:00:00:01";
      }
    ];

    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
      {
        proto = "virtiofs";
        tag = "ssh-keys";
        source = "/var/lib/microvms/frieren-canary/ssh-host-keys";
        mountPoint = "/etc/ssh/host-keys";
      }
    ];

    writableStoreOverlay = "/nix/.rw-store";

    volumes = [
      {
        mountPoint = "/var";
        image = "var.img";
        size = 2048;
      }
    ];
  };

  networking.hostName = "frieren-canary";
  networking.firewall.enable = false;

  # Network configuration matching host bridge microbr (192.168.83.1/24)
  networking.useNetworkd = true;
  networking.useDHCP = false;
  networking.nameservers = ["1.1.1.1" "8.8.8.8"];

  systemd.network.enable = true;
  systemd.network.networks."10-e" = {
    matchConfig.Name = "e*";
    addresses = [{Address = "192.168.83.10/24";}];
    routes = [{Gateway = "192.168.83.1";}];
  };

  # SSH Daemon with persistent host keys
  services.openssh = {
    enable = true;
    hostKeys = [
      {
        path = "/etc/ssh/host-keys/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  users.users.devji = {
    isNormalUser = true;
    home = "/home/devji";
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys =
      config.ssh.authorizedKeys.keys
      ++ [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHnNR7isgO8VDY76XzwyH3mOg1/DQo8dZgqQOfziw0DQ devji@nixos"
      ];
  };

  # Passwordless sudo for devji inside canary sandbox
  security.sudo.wheelNeedsPassword = false;

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
            mkdir -p /home/devji/.subzeroclaw/skills /home/devji/.subzeroclaw/logs /home/devji/workspace/subzeroclaw
            # SubZeroClaw config: written unconditionally (the canary is
            # ephemeral; the config is managed, not user-owned). The runner
            # (SubZeroClaw, in this microVM) talks only to the host
            # (192.168.83.1); frieren's nginx /eisen/ proxies to Eisen's
            # decision router (via Eisen's nginx /router/). The model is
            # policy:auto, so the router uses its Nix default (Kolibri).
            # api_key "none": the router forwards it to Jev; Jev rejects it
            # and the router falls back to Laya (fine for the hi test). For
            # real Jev decisions, set the real key via a secret (never here).
            cat << 'EOF' > /home/devji/.subzeroclaw/config
      api_key  = "none"
      endpoint = "http://192.168.83.1/eisen/v1/chat/completions"
      request_extra = {"model":"policy:auto"}
      skills_dir = "/home/devji/.subzeroclaw/skills"
      log_dir    = "/home/devji/.subzeroclaw/logs"
      EOF

            if [ ! -f /home/devji/.subzeroclaw/skills/sandbox.md ]; then
              cat << 'EOF' > /home/devji/.subzeroclaw/skills/sandbox.md
      # Sandboxed Agent in NixOS MicroVM
      You are an autonomous agent running inside an isolated NixOS Cloud-Hypervisor MicroVM.
      Use the shell tool to run commands, inspect the environment, edit code, and compile software.
      Your workspace contains the source code of this agent harness at `/home/devji/workspace/subzeroclaw`.
      You are free to explore, create files, write scripts, or modify your own C source code.
      EOF
            fi

            if [ ! -f /home/devji/workspace/subzeroclaw/Makefile ]; then
              cp -r ${subzeroclaw}/share/subzeroclaw/* /home/devji/workspace/subzeroclaw/ 2>/dev/null || true
              chmod -R u+rw /home/devji/workspace/subzeroclaw/ 2>/dev/null || true
            fi

            chown -R devji:users /home/devji/.subzeroclaw /home/devji/workspace 2>/dev/null || true
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

      with socketserver.TCPServer(("0.0.0.0", 8080), Handler) as httpd:
          httpd.serve_forever()
    '';
  in {
    description = "Dummy HTTP Service for Model B Reverse Proxy Verification";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${serverScript}";
      Restart = "always";
      DynamicUser = true;
    };
  };

  system.stateVersion = "26.11";

  # Prevent shutdown unmount deadlock on shared virtiofs store
  systemd.mounts = [
    {
      what = "store";
      where = "/nix/store";
      overrideStrategy = "asDropin";
      unitConfig.DefaultDependencies = false;
    }
  ];
}
