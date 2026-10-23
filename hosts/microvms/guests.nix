# `microvm.vms.<name>` for a host that runs guests. One guest: a shell sandbox
# by default, and the host's service tier when `services = true` (delphi runs
# the two stub HTTP services there, proxied under /microvm/). `persist` gives a
# service real state on a disk, `stirling` adds a real app, and `slidesUser`
# turns an account's login into a terminal deck under ssh. Rationale: AGENTS.nix
# `microvm-guests`.
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
  # Persistent state, one ext4 image per entry, keyed by name:
  #   persist = { hermes = { }; stirling = { size = 2048; }; }
  # `mountPoint` defaults to /var/lib/<name>. The image lives on the HOST at
  # `<stateRoot>/sandbox/volumes/<name>.img` and is created (mkfs, label = name)
  # before first start, so a ported service's StateDirectory survives a guest
  # restart with no host-side file ownership to negotiate.
  persist ? {},
  # A guest user whose only login is `slides` reading ./slideshow.md. null = no
  # such account.
  slidesUser ? null,
  # Stirling PDF behind the host's /microvm/stirling/, with its state on the
  # `stirling` volume. Off by default: it is a JVM app, not a stub.
  stirling ? false,
  # Host port forwarded to the guest's sshd. null = reachable only from the host
  # and the brlan subnet; the listener is always the host's, so the guest itself
  # gains no inbound path.
  exposeSsh ? null,
  mem ? 1024,
}: {
  config,
  lib,
  pkgs,
  ...
}: let
  sshHostKeys = "${stateRoot}/sandbox/ssh-host-keys";

  # A second keypair, this one a CLIENT key: the host holds the private half and
  # the guest trusts the public half, so a host-side forced command can open the
  # deck on a port the edge already carries (22) without the client ever holding
  # a guest credential. It lives under the shared host-key directory, which is
  # already mounted in the guest at /etc/ssh/host-keys.
  hopDir = "${sshHostKeys}/hop";
  hopKeyFile = "${hopDir}/id_ed25519";
  hopKnownHosts = "${hopDir}/known_hosts";
  # Outside the state root on purpose (see base.nix): sshd will only read an
  # authorized_keys that root owns, along with every directory above it.
  hopAuthDir = "/srv/microvm/hop-auth";
  hopTarget = "${slidesUser}@${address}";
  # The forced command that runs the hop is an ordinary account, not root, so
  # the keypair is group-readable and the host config puts that account in this
  # group. Nothing else on the host is: the guest's own private host key in the
  # same directory stays 0600.
  hopGroup = "microvm-deck-hop";

  # Compiled from the repo, so the deck is a store path the guest already sees
  # over the virtiofs /nix/store share.
  deck = ./slideshow.md;

  # One volume per persisted name. A label rather than a /dev/vdX letter: disk
  # enumeration order is not a stable identity.
  persistVolumes =
    lib.mapAttrsToList (name: opts: {
      image = "${stateRoot}/sandbox/volumes/${name}.img";
      label = name;
      mountPoint = opts.mountPoint or "/var/lib/${name}";
      size = opts.size or 1024;
    })
    persist;

  # Both halves of the deck entry — the port and the account — are published so
  # the host's proxy page names exactly what this module created.
  sshEnabled = exposeSsh != null && slidesUser != null;

  # Stirling PDF 3.1.0 from the upstream release jar. nixpkgs' `stirling-pdf` is
  # unfree (no binary cache) and builds the frontend and JVM tree from source —
  # hours on this host — while this jar is architecture-independent, so an
  # aarch64 guest runs the same artifact the x86_64 build would.
  stirlingJar = pkgs.fetchurl {
    url = "https://github.com/Stirling-Tools/Stirling-PDF/releases/download/v3.1.0/Stirling-PDF-server.jar";
    hash = "sha256-1ELrlhDx02fcTa8sJw8rZvq9o6VX/OD7gdzWix66XCM=";
  };
  stirlingPort = 8082;
  stirlingPath = "/microvm/stirling";

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
  # address, the port pair, the deck account and its port have one home.
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
    sshPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = exposeSsh;
      description = "Host port forwarded to the guest's sshd (null = not forwarded).";
    };
    sshUser = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = slidesUser;
      description = "Guest account whose login runs the deck (null = no deck).";
    };
    # A host-side forced command can reach the deck through this keypair without
    # the client holding a guest credential. Published rather than hard-coded in
    # the host config: the paths belong to this module's state directory.
    sshHopTarget = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default =
        if slidesUser != null
        then hopTarget
        else null;
      description = "ssh destination for a host-side hop into the deck (null = no hop).";
    };
    sshHopKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default =
        if slidesUser != null
        then hopKeyFile
        else null;
      description = "Host-side private key of the hop keypair.";
    };
    sshHopKnownHosts = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default =
        if slidesUser != null
        then hopKnownHosts
        else null;
      description = "known_hosts pinned to the guest's own host key.";
    };
    sshHopGroup = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default =
        if slidesUser != null
        then hopGroup
        else null;
      description = "Group a forced-command account must belong to in order to read the hop key.";
    };
    stirling = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default =
        if stirling
        then stirlingPort
        else null;
      description = "Stirling PDF port inside the guest (null = not installed).";
    };
    stirlingPath = lib.mkOption {
      type = lib.types.str;
      default = stirlingPath;
      description = "URL prefix the host serves Stirling on; the app's context path, so one string";
    };
  };

  config = {
    # microvm.nix bounds a start at 150 s, which assumes KVM. A TCG boot takes
    # minutes, so without this the unit is killed mid-boot and reports a timeout
    # while the guest is still healthy.
    systemd.services."microvm@sandbox".serviceConfig.TimeoutStartSec = lib.mkIf (cpu != null) "900";

    # The runner user must own the state dir: microvm-set-booted@ writes `current`
    # there, the keygen unit below writes the key as the same user, and the
    # volume images are created there before the guest starts.
    systemd.tmpfiles.rules =
      [
        "d ${stateRoot} 0755 microvm kvm -"
        "d ${stateRoot}/sandbox 0755 microvm kvm -"
        # Trailable by the hop group when there is one: its members read the hop
        # key, and the guest's own private host key stays 0600.
        "d ${sshHostKeys} ${
          if slidesUser != null
          then "0750"
          else "0700"
        } microvm ${
          if slidesUser != null
          then hopGroup
          else "kvm"
        } -"
      ]
      ++ lib.optional (persist != {}) "d ${stateRoot}/sandbox/volumes 0700 microvm kvm -";

    users.groups = lib.mkIf (slidesUser != null) {${hopGroup} = {};};

    # One key per guest, generated once and served to the guest over virtiofs.
    # Without this every boot runs sshd-keygen under TCG, which took minutes and
    # gave the guest a new identity each time.
    systemd.services.microvm-sandbox-ssh-host-keys = {
      description = "Persistent SSH keys for the sandbox microVM";
      before = ["microvm@sandbox.service"];
      requiredBy = ["microvm@sandbox.service"];
      serviceConfig = {
        Type = "oneshot";
        User = "microvm";
        Group = "kvm";
        SupplementaryGroups = lib.optional (slidesUser != null) hopGroup;
        UMask = "0077";
        # sshd's StrictModes accepts an `AuthorizedKeysFile` outside the home only
        # when root owns it; a file owned by the share's runner user is refused
        # with nothing but "Permission denied (publickey)" on the client. The
        # `+` runs this one command with full privileges inside a User= unit, so
        # the public half lands root-owned while the private half stays with the
        # hop group — the guest can read the key it must trust, never the one the
        # host signs with.
        ExecStartPost =
          lib.optional (slidesUser != null) "+${pkgs.coreutils}/bin/install -d -o root -g root -m 0755 ${hopAuthDir}"
          ++ lib.optional (slidesUser != null) "+${pkgs.coreutils}/bin/install -o root -g root -m 0644 ${hopKeyFile}.pub ${hopAuthDir}/authorized_keys";
      };
      script =
        ''
          ${pkgs.coreutils}/bin/install -d -m 0700 ${sshHostKeys}
          key=${sshHostKeys}/ssh_host_ed25519_key
          [ -s "$key" ] || ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -C "sandbox" -f "$key"
        ''
        + lib.optionalString (slidesUser != null) ''
          # The hop's credential. The public half goes to a root-owned directory
          # the guest mounts (see ExecStartPost); the private half never leaves
          # the host and is group-readable only by the forced-command account.
          ${pkgs.coreutils}/bin/install -d -m 0750 ${hopDir}
          [ -s ${hopKeyFile} ] || ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -C "sandbox-hop" -f ${hopKeyFile}
          # Pinned from the guest's own host key, so the hop is `StrictHostKeyChecking=yes`
          # and not accept-new: the guest's identity is this file, not trust on first use.
          printf '%s %s\n' '${address}' "$(${pkgs.coreutils}/bin/cut -d' ' -f1,2 ${sshHostKeys}/ssh_host_ed25519_key.pub)" > ${hopKnownHosts}
          # UMask 0077 wrote all of it 0600; the group is how the forced-command
          # account reads the key without running as root. Deliberately not `-R`:
          # the guest's own host key in this directory belongs to root, and the
          # runner user cannot change its group — a recursive chgrp fails the unit.
          ${pkgs.coreutils}/bin/chgrp ${hopGroup} ${hopDir} ${sshHostKeys}
          ${pkgs.coreutils}/bin/chmod 0750 ${sshHostKeys} ${hopDir}
          ${pkgs.coreutils}/bin/chmod 0640 ${hopKeyFile} ${hopKeyFile}.pub ${hopKnownHosts}
        '';
    };

    # The deck's door. nginx proxies HTTP, and ssh is not HTTP, so this is a
    # socket-activated TCP forward: connections are accepted by the host and
    # handed to the guest's sshd, which means nothing listens inside the guest
    # that the host did not open.
    systemd.sockets.microvm-sandbox-ssh = lib.mkIf sshEnabled {
      wantedBy = ["sockets.target"];
      listenStreams = ["0.0.0.0:${toString exposeSsh}"];
      socketConfig = {
        Accept = false;
        NoDelay = true;
      };
    };

    systemd.services.microvm-sandbox-ssh = lib.mkIf sshEnabled {
      description = "Forward tcp/${toString exposeSsh} to the sandbox guest's sshd";
      requires = ["microvm-sandbox-ssh.socket"];
      after = ["microvm-sandbox-ssh.socket"];
      serviceConfig.ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd ${address}:22";
    };

    networking.firewall.allowedTCPPorts = lib.optional sshEnabled exposeSsh;

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
      config = {config, ...}: {
        imports = [
          inputs.microvm.nixosModules.microvm
          (import ./base.nix {
            hostName = "sandbox";
            ipAddress = address;
            inherit hypervisor cpu tapId sshHostKeys mem;
            hopAuthDir =
              if slidesUser != null
              then hopAuthDir
              else null;
            mac = "02:00:00:00:83:11";
          })
        ];

        # TCG (cpu = "max") boots this guest in minutes, and systemd's 90 s device
        # timeout expires while udev is still coldplugging — the volumes then land
        # in emergency mode with "Timed out waiting for device
        # /dev/disk/by-label/…". A KVM guest does not need the slack.
        systemd.settings.Manager.DefaultDeviceTimeoutSec = lib.mkIf (cpu != null) "600";
        # nixpkgs caps the console at 4; on an emulated guest the kernel's device
        # messages are the only place a missing disk shows up.
        boot.consoleLogLevel = lib.mkIf (cpu != null) 7;

        microvm.volumes = persistVolumes;

        # One account, one command. No password is set, and `base.nix` turns
        # password auth off for the whole guest, so this account exists only to
        # match a key from the fleet's one key list.
        users.groups.stirling = lib.mkIf stirling {};
        users.users = lib.mkMerge [
          (lib.optionalAttrs (slidesUser != null) {
            ${slidesUser} = {
              isNormalUser = true;
              description = "Terminal deck over ssh (forced command)";
              openssh.authorizedKeys.keys = config.ssh.authorizedKeys.keys;
            };
          })
          (lib.optionalAttrs stirling {
            stirling = {
              isSystemUser = true;
              group = "stirling";
              home = "/var/lib/stirling-pdf";
              description = "Stirling PDF";
            };
          })
        ];

        # The state volume mounts at /var/lib/stirling-pdf, so these are real
        # directories on the image, not in a tmpfs the JVM can outgrow.
        systemd.tmpfiles.rules = lib.optionals stirling [
          "d /var/lib/stirling-pdf/tmp 0700 stirling stirling -"
          "d /var/lib/stirling-pdf/jpdfium 0700 stirling stirling -"
          "d /var/lib/stirling-pdf/configs 0700 stirling stirling -"
        ];

        # Last block in sshd_config — the only place a Match may appear. The
        # login is the deck: no shell to escape to, no forwarding, and the deck
        # itself is a read-only store path.
        # `AuthorizedKeysFile` lists every path because the directive REPLACES the
        # default instead of adding to it, and NixOS puts a user's keys in
        # /etc/ssh/authorized_keys.d/<user> — not in the home directory — so that
        # entry has to be named back explicitly. The hop key comes from the shared
        # directory, which is how the host-side door reaches this account. A guest
        # user therefore accepts either key, and neither is a password.
        services.openssh.extraConfig = lib.mkIf (slidesUser != null) ''
          Match User ${slidesUser}
            ForceCommand ${pkgs.slides}/bin/slides ${deck}
            AuthorizedKeysFile %h/.ssh/authorized_keys /etc/ssh/authorized_keys.d/%u /etc/ssh/hop-auth/authorized_keys
            AllowTcpForwarding no
            AllowAgentForwarding no
            X11Forwarding no
            PermitTunnel no
        '';

        # busybox httpd, not nginx: a stub is a directory and a listener, and the
        # guest's closure is paid for on every TCG start. Stirling shares this
        # attribute set because one attrset cannot define `systemd.services`
        # twice; the `optionalAttrs` is what keeps it off by default.
        systemd.services =
          lib.listToAttrs (map (svc: {
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
            stubServices)
          // lib.optionalAttrs stirling {
            # A release jar, a JRE and the CLI tools the app shells out to. The
            # jar is architecture-independent; every tool here is in nixpkgs for
            # aarch64. LibreOffice and Calibre are deliberately absent — the beta
            # Office conversion is the only feature they serve, and each is a
            # large closure the guest would carry on every TCG start.
            stirling = {
              description = "Stirling PDF inside the sandbox microVM";
              wantedBy = ["multi-user.target"];
              after = ["network.target"];
              path = with pkgs; [
                which
                qpdf
                tesseract
                poppler-utils
                unpaper
                ghostscript_headless
                ocrmypdf
              ];
              environment = {
                SERVER_PORT = toString stirlingPort;
                # The app's own root and the proxied path must be one string, or
                # every absolute URL the frontend emits points outside /microvm/.
                SERVER_SERVLET_CONTEXT_PATH = stirlingPath;
                CONFIGS = "/var/lib/stirling-pdf/configs";
                # TCG spends its time interpreting bytecode, so the heap stays
                # small enough for the guest budget and the state volume absorbs
                # the rest.
                JDK_JAVA_OPTIONS = "-Xmx1280m -Djava.io.tmpdir=/var/lib/stirling-pdf/tmp -Djpdfium.native.cacheDir=/var/lib/stirling-pdf/jpdfium";
              };
              serviceConfig = {
                ExecStart = "${pkgs.jdk25_headless}/bin/java -jar ${stirlingJar}";
                User = "stirling";
                Group = "stirling";
                StateDirectory = "stirling-pdf";
                StateDirectoryMode = "0700";
                WorkingDirectory = "/var/lib/stirling-pdf";
                Restart = "on-failure";
                RestartSec = "10s";
                # Spring Boot on an emulated vCPU is minutes, not seconds.
                TimeoutStartSec = "900";
                PrivateTmp = true;
                NoNewPrivileges = true;
              };
            };
          };
      };
    };
  };
}
