# `microvm.vms.<name>` for a host that runs guests. One guest: a shell sandbox
# by default, and the host's service tier when `services = true` (delphi runs
# the two stub HTTP services there, proxied under /microvm/). Rationale:
# AGENTS.nix `microvm-guests`.
{
  inputs,
  hypervisor ? "cloud-hypervisor",
  # A KVM-less host (delphi: OCI A1 does not expose EL2) names a CPU ("max") so
  # the runner uses TCG. cloud-hypervisor has no TCG backend, so such a host
  # must also select hypervisor = "qemu".
  cpu ? null,
  tapId ? "microvm3",
  address ? "192.168.83.11",
  stateRoot ? "/var/lib/microvms",
  # A guest exists to be started on purpose; a host that serves from it wants it
  # back after a reboot instead.
  autostart ? false,
  # The two stub HTTP services the host proxy exposes under /microvm/. Off by
  # default: a shell sandbox should not carry web servers.
  services ? false,
  mem ? 1024,
}: {
  lib,
  pkgs,
  ...
}: let
  sshHostKeys = "${stateRoot}/sandbox/ssh-host-keys";

  # One page per stub. The page names its upstream so a browser at
  # /microvm/<name>/ can prove which guest answered.
  stubRoot = svc:
    pkgs.writeTextDir "index.html" ''
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8">
          <title>microvm stub — ${svc.name}</title>
        </head>
        <body style="font-family: system-ui, sans-serif; margin: 3rem; max-width: 40rem">
          <h1>microvm stub: ${svc.name}</h1>
          <p>Served from the <code>sandbox</code> microVM on delphi.</p>
          <p>Upstream <code>${address}:${toString svc.port}</code>, exposed at
            <code>/microvm/${svc.name}/</code> on the public hostname and on the tailnet name.</p>
        </body>
      </html>
    '';

  stubServices = [
    {
      name = "one";
      port = 8080;
    }
    {
      name = "two";
      port = 8081;
    }
  ];
in {
  imports = [inputs.microvm.nixosModules.host];

  # The host side of these stubs is generated from this declaration, so the
  # address and the port pair have exactly one home.
  options.microvmGuests.sandbox = {
    address = lib.mkOption {
      type = lib.types.str;
      default = address;
      description = "brlan address of the sandbox guest, for host-side proxies.";
    };
    services = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {type = lib.types.str;};
          port = lib.mkOption {type = lib.types.port;};
        };
      });
      default = lib.optionals services (map (svc: {inherit (svc) name port;}) stubServices);
      description = "Stub HTTP services running inside the sandbox guest.";
    };
  };

  config = {
    # microvm.nix bounds a start at 150 s, which assumes KVM. A TCG boot takes
    # minutes, so without this the unit is killed mid-boot and reports a timeout
    # while the guest is still healthy.
    systemd.services."microvm@sandbox".serviceConfig.TimeoutStartSec = lib.mkIf (cpu != null) "900";

    # The runner user must own the state dir: microvm-set-booted@ writes `current`
    # there, and the keygen unit below writes the key as the same user.
    systemd.tmpfiles.rules = [
      "d ${stateRoot} 0755 microvm kvm -"
      "d ${stateRoot}/sandbox 0755 microvm kvm -"
      "d ${sshHostKeys} 0700 microvm kvm -"
    ];

    # One key per guest, generated once and served to the guest over virtiofs.
    # Without this every boot runs sshd-keygen under TCG, which took minutes and
    # gave the guest a new identity each time.
    systemd.services.microvm-sandbox-ssh-host-keys = {
      description = "Persistent SSH host key for the sandbox microVM";
      before = ["microvm@sandbox.service"];
      requiredBy = ["microvm@sandbox.service"];
      serviceConfig = {
        Type = "oneshot";
        User = "microvm";
        Group = "kvm";
        UMask = "0077";
      };
      script = ''
        ${pkgs.coreutils}/bin/install -d -m 0700 ${sshHostKeys}
        key=${sshHostKeys}/ssh_host_ed25519_key
        [ -s "$key" ] || ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -C "sandbox" -f "$key"
      '';
    };

    # `ssh sandbox` from the host that runs it, as root: the bridge subnet is
    # host-local, so this name means nothing on another machine.
    programs.ssh.extraConfig = ''
      Host sandbox
        HostName ${address}
        User root
        IdentityFile ~/.ssh/id_ed25519
        StrictHostKeyChecking accept-new
        # 3 s was tight enough to fail the banner exchange on a TCG guest whose
        # vCPUs are busy finishing boot; 30 s still fails fast on a dead guest.
        ConnectTimeout 30
        # OpenSSH 10 puts sntrup761x25519 first; that KEX takes about a minute
        # in a TCG guest, so the handshake times out before the banner. Curve25519
        # is instant and still the modern choice.
        KexAlgorithms curve25519-sha256
    '';

    microvm.vms.sandbox = {
      inherit autostart;
      config = {
        imports = [
          inputs.microvm.nixosModules.microvm
          (import ./base.nix {
            hostName = "sandbox";
            ipAddress = address;
            inherit hypervisor cpu tapId sshHostKeys mem;
            mac = "02:00:00:00:83:11";
          })
        ];

        # busybox httpd, not nginx: a stub is a directory and a listener, and the
        # guest's closure is paid for on every TCG start.
        systemd.services = lib.listToAttrs (map (svc: {
            name = "microvm-stub-${svc.name}";
            value = lib.mkIf services {
              description = "Stub HTTP service '${svc.name}' inside the sandbox microVM";
              wantedBy = ["multi-user.target"];
              after = ["network.target"];
              serviceConfig = {
                ExecStart = "${pkgs.busybox}/bin/httpd -f -p 0.0.0.0:${toString svc.port} -h ${stubRoot svc}";
                Restart = "always";
                RestartSec = "2s";
                DynamicUser = true;
              };
            };
          })
          stubServices);
      };
    };
  };
}
