# NAS client: mount frieren's `/data` export at /Volumes/data.
{
  config,
  lib,
  pkgs,
  ...
}: let
  mountPoint = "/Volumes/data";
  lanServer = "192.168.3.25"; # frieren, static LAN address
  tailnetServer = "100.97.61.65"; # frieren over Tailscale
  exportPath = "/data"; # NFSv4 pseudo-root → /export/data on frieren

  # NFSv4 keeps everything on 2049, so one TCP connect is a cheap, bounded
  # reachability probe.
  probeTool = pkgs.writeShellScriptBin "nas-reachable" ''
    exec timeout 3 bash -c "exec 3<>/dev/tcp/$1/2049"
  '';

  governor = pkgs.writeShellScriptBin "nas-path-governor" ''
    set -u

    MP="${mountPoint}"
    # Overridable so the fallback and re-homing paths can be exercised on a
    # live host without unplugging anything.
    LAN="''${NAS_GOVERNOR_LAN:-${lanServer}}"
    TS="''${NAS_GOVERNOR_TS:-${tailnetServer}}"
    EXPORT="''${NAS_GOVERNOR_EXPORT:-${exportPath}}"

    log() { echo "nas-path-governor: $*"; }
    reachable() { ${probeTool}/bin/nas-reachable "$1" 2>/dev/null; }

    # Detection is done from the mount table, never by touching the path: a
    # syscall on the mountpoint triggers the automount as a side effect, which
    # would make every check a mount attempt. The autofs cover reports its
    # source as "systemd-1" (no colon), so filtering on ':/' skips it, and
    # `tail -n1` picks the topmost mount when the cover and the NFS mount are
    # stacked.
    nfs_source() {
      findmnt -n -o SOURCE --target "$MP" 2>/dev/null | grep ':/' | tail -n1
    }

    # An access-triggered automount completes *after* the triggering call has
    # returned: `ls` followed by an immediate check reports "no mount" even
    # though it appears moments later (measured on fern). So trigger once, then
    # poll the mount table.
    wait_for_lan() {
      tries="''${NAS_GOVERNOR_WAIT:-16}" # 16 × 0.5 s = 8 s
      n=1
      while [ "$n" -le "$tries" ]; do
        case "$(nfs_source)" in "$LAN":*) return 0 ;; esac
        sleep 0.5
        n=$((n + 1))
      done
      return 1
    }

    # LAN: let systemd's automount do it, so the mount stays tracked and keeps
    # its idle-timeout unmount. reset-failed first: an earlier boot-time
    # failure must not leave a start limit blocking the retry.
    mount_lan() {
      systemctl reset-failed "Volumes-data.mount" 2>/dev/null || true
      ls "$MP" >/dev/null 2>&1 || true
      wait_for_lan
    }

    # Tailnet: systemd cannot do this one — its What= is the LAN address.
    mount_tailnet() {
      mount -t nfs -o "soft,timeo=100,retrans=2,vers=4.2" "$TS:$EXPORT" "$MP"
    }

    attempts="''${NAS_GOVERNOR_ATTEMPTS:-1}"
    delay="''${NAS_GOVERNOR_DELAY:-5}"

    i=1
    while [ "$i" -le "$attempts" ]; do
      cur="$(nfs_source)"

      case "$cur" in
        "$TS":*)
          # Currently on the overlay: hand the path back to the LAN as soon as
          # it is reachable again, so the wire is preferred when we are home.
          if reachable "$LAN"; then
            if umount "$MP" 2>/dev/null; then
              log "LAN is back — unmounted $cur, the automount takes over"
            else
              log "LAN is back but $MP is busy; keeping $cur for now"
              exit 0
            fi
          else
            log "mounted over tailnet ($cur)"
            exit 0
          fi
          ;;
        "$LAN":*) log "mounted from LAN ($cur)"; exit 0 ;;
      esac

      if reachable "$LAN"; then
        if mount_lan; then log "mounted from LAN ($(nfs_source))"; exit 0; fi
        log "LAN reachable but no mount appeared within the wait (attempt $i)"
      elif reachable "$TS"; then
        if mount_tailnet 2>/dev/null; then log "mounted over tailnet ($(nfs_source))"; exit 0; fi
        log "tailnet reachable but the mount failed (attempt $i)"
      else
        log "no NFS server reachable — LAN $LAN and tailnet $TS both down (attempt $i)"
      fi

      i=$((i + 1))
      [ "$i" -le "$attempts" ] && sleep "$delay"
    done

    # A laptop that is genuinely offline must not fail a unit on every boot.
    # The timer retries every 5 minutes and `nas-recover` forces it now.
    log "giving up for now — $MP stays unmounted until a server is reachable"
    exit 0
  '';

  # See the module header: nix-gc dies on a GC root that lives on an absent NAS.
  gcRootGuard = pkgs.writeShellScriptBin "nas-gc-root-guard" ''
    set -u
    MP="${mountPoint}"

    # Absolute tool paths on purpose: this runs as nix-gc's ExecStartPre and
    # that unit's PATH carries neither util-linux (findmnt) nor extra GNU tools.
    # A tool that failed to resolve here would make the mount test report
    # "not mounted" and prune roots that are perfectly alive.
    findmnt=${pkgs.util-linux}/bin/findmnt
    grep=${pkgs.gnugrep}/bin/grep
    tail=${pkgs.coreutils}/bin/tail
    readlink=${pkgs.coreutils}/bin/readlink
    rm=${pkgs.coreutils}/bin/rm

    if [ -n "$("$findmnt" -n -o SOURCE --target "$MP" 2>/dev/null | "$grep" ':/' | "$tail" -n1)" ]; then
      exit 0
    fi

    for link in /nix/var/nix/gcroots/auto/*; do
      [ -L "$link" ] || continue
      target="$("$readlink" "$link")"
      case "$target" in
        "$MP"/*)
          echo "nas-gc-root-guard: pruning unreachable NAS gcroot $link -> $target"
          "$rm" -f "$link"
          ;;
      esac
    done
  '';

  # NetworkManager's dispatcher.d has ONE directory for plain "basic" hooks and
  # two event-specific ones (pre-up.d, pre-down.d); the up/down *events* are all
  # delivered to the basic hook, and the event name arrives as $2. NixOS models
  # exactly that (`types.enum ["basic" "pre-up" "pre-down"]`), so a hook asking
  # for `type = "up"` fails evaluation outright — upstream's own example filters
  # on $2 from inside a basic hook instead. That is what this does.
  dispatcherScript = pkgs.writeShellScript "nas-nm-dispatcher" ''
    # Network state changed: re-evaluate which server the path should use.
    case "''${2:-}" in
      up | post-up | pre-down | down | connectivity-change) ;;
      *) exit 0 ;;
    esac
    # Absolute path on purpose — NM dispatcher scripts do not inherit a PATH
    # that is guaranteed to contain systemd. --no-block: the dispatcher must
    # never wait on the governor (it probes the network with a 3 s timeout).
    exec ${pkgs.systemd}/bin/systemctl start --no-block nas-path-governor.service
  '';
in
  # Skip the NAS mount on the NAS host itself (frieren does not mount itself).
  lib.mkIf (config.networking.hostName != "frieren") {
    environment.systemPackages = [
      pkgs.nfs-utils
      governor
      (pkgs.writeShellScriptBin "nas-recover" ''
        echo "Recovering /Volumes/data NAS mount..."
        sudo ${pkgs.systemd}/bin/systemctl start nas-path-governor.service
        if ls /Volumes/data >/dev/null 2>&1; then
          echo "Successfully mounted /Volumes/data!"
        else
          echo "Still no mount: neither the NAS on the LAN (${lanServer}) nor over the tailnet (${tailnetServer}) is reachable right now."
        fi
      '')
    ];

    fileSystems.${mountPoint} = {
      device = "${lanServer}:${exportPath}";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "_netdev"
        "nofail"
        "noauto"
        "x-systemd.idle-timeout=60"
        "x-systemd.device-timeout=5s"
        "x-systemd.mount-timeout=8s"
        # Roaming-safe: bounded RPC timeouts, never an indefinite block.
        # See the module header for why this is not `hard`.
        "soft"
        "timeo=100"
        "retrans=2"
      ];
    };

    systemd.units = {
      # A failed boot-time access must not lock the automount out.
      "Volumes-data.automount.d/50-recovery.conf".text = ''
        [Unit]
        StartLimitIntervalSec=0
      '';
      # When an access-triggered mount fails (WiFi not up yet, LAN gone, NAS
      # rebooting) the governor takes over at once: it retries the LAN and
      # falls back to the tailnet instead of leaving the path dead until the
      # next stray access.
      "Volumes-data.mount.d/50-recovery.conf".text = ''
        [Unit]
        StartLimitIntervalSec=0
        OnFailure=nas-path-governor.service
      '';
    };

    systemd.services.nas-path-governor = {
      description = "Ensure /Volumes/data is mounted (LAN first, tailnet fallback)";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      # The script calls findmnt/mount/umount/systemctl by name: give the unit
      # an explicit PATH instead of relying on the manager's default.
      path = with pkgs; [
        bash
        coreutils
        findutils
        gnugrep
        nfs-utils
        systemd
        util-linux
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${governor}/bin/nas-path-governor";
        # The WiFi association/DHCP race on a laptop can outlive
        # network-online.target, so the boot run retries for ~30 s.
        Environment = [
          "NAS_GOVERNOR_ATTEMPTS=6"
          "NAS_GOVERNOR_DELAY=5"
        ];
      };
    };

    systemd.timers.nas-path-governor = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "15s";
        # Also re-home the path back to the LAN after roaming (hotel → home).
        OnUnitActiveSec = "5min";
        AccuracySec = "30s";
        Persistent = false;
      };
    };

    # Re-evaluate on every interface change, not only on the timer.
    networking.networkmanager.dispatcherScripts = [
      {
        type = "basic"; # must be basic; the event filter lives in the script
        source = dispatcherScript;
      }
    ];

    # nix-gc runs at boot (Persistent catch-up) — long before any userland
    # access would have triggered the automount. Ensure the path first, then
    # drop the roots that point into an absent NAS so GC still completes.
    systemd.services.nix-gc = lib.mkIf config.nix.gc.automatic {
      wants = ["nas-path-governor.service"];
      after = ["nas-path-governor.service"];
      serviceConfig.ExecStartPre = "${gcRootGuard}/bin/nas-gc-root-guard";
    };
  }
