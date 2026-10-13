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
}: {
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
    git
    curl
    jq
    sqlite
    procps
    htop
    python3
  ];

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
