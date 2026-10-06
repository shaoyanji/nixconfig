# iventoy — PXE boot server for the /Volumes/data/isos collection.
#
# Serves the ISO library over PXE/HTTPBoot to UEFI + Legacy BIOS clients on
# 192.168.3.0/24 WITHOUT running a competing DHCP server: the router
# (192.168.3.1) owns all DHCP leases. iVentoy's Proxy/ProxyNet modes only
# ANSWER with next-server + bootfile options (they never lease IPs).
#
# Ports (upstream doc_portnum):
#   UDP 67/69  DHCP-proxy/TFTP (ProxyNet listens on 67 too)
#   UDP 4011   ProxyDHCP
#   TCP 16000  PXE HTTP streaming
#   TCP 26000  Web management UI
#
# ONE-TIME MANUAL STEP (first start only — web UI is up regardless):
#   1. Open http://frieren.lan:26000
#   2. Configuration -> DHCP Server Mode -> "ProxyNet" (iVentoy on Linux,
#      router DHCP on a different OS — see upstream doc_ext_dhcp).
#   3. Select server IP 192.168.3.25 / enp1s0, then click the green Start
#      button once. Settings persist in /srv/iventoy/data/iventoy.dat and
#      the -R auto-start flag replays them on every subsequent boot.
#   NOTE: until the green Start is clicked, only the web UI runs — no DHCP
#   service is active, so there is zero risk to the LAN's DHCP.
{
  pkgs,
  lib,
  ...
}:
let
  iventoy = pkgs.stdenv.mkDerivation {
    pname = "iventoy";
    version = "1.0.20";

    # Same tarball as /Volumes/data/isos/appliances/iventoy-1.0.20-linux-free.tar.gz
    # (hash-verified identical to the upstream release asset).
    src = pkgs.fetchurl {
      url = "https://github.com/ventoy/PXE/releases/download/v1.0.20/iventoy-1.0.20-linux-free.tar.gz";
      hash = "sha256-4p/teSGw77vOs3G3EKsg2nWOO2RWyOcTaUaQaJoc8Rk=";
    };

    sourceRoot = "iventoy-1.0.20";
    dontBuild = true;
    dontConfigure = true;
    # stdenv's fixup (strip/patch-shebangs) would alter the binary and trip
    # iVentoy's self-checksum ("checksum not match"). Keep every byte intact.
    dontStrip = true;
    dontFixup = true;
    dontPatchShebangs = true;
    # NOTE: do NOT patchelf the binary — iVentoy self-checksums lib/iventoy
    # and refuses to start ("checksum not match") on any modification.
    # Instead the service bind-mounts a working glibc loader over /lib64
    # (see BindReadOnlyPaths below) and uses LD_LIBRARY_PATH for the
    # bundled lib/lin64 dependencies.

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/iventoy
      cp -r ./* $out/share/iventoy/
      runHook postInstall
    '';

    meta = with lib; {
      description = "iVentoy network PXE boot server (free edition)";
      sourceProvenance = with sourceTypes; [ binaryNativeCode ];
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
      mainProgram = "iventoy";
    };
  };

  # Refresh program files from the store on every start while preserving the
  # runtime state (data/ holds the persisted web-UI config; log/ is history).
  # The ISO dir is a symlink — upstream-recommended so ISOs are never
  # duplicated and the collection stays on the data drive.
  syncScript = pkgs.writeShellScript "iventoy-sync" ''
    set -euo pipefail
    SRC=${iventoy}/share/iventoy
    DST=/srv/iventoy

    mkdir -p "$DST"
    for d in lib user doc; do
      rm -rf "$DST/$d"
      cp -a "$SRC/$d" "$DST/"
    done
    install -m 0755 "$SRC/iventoy.sh" "$DST/iventoy.sh"

    if [ ! -e "$DST/data/iventoy.dat" ]; then
      mkdir -p "$DST/data"
      cp -a "$SRC/data/." "$DST/data/"
    fi
    # iventoy writes runtime state into data/ (config changes, a fallback
    # sysfs tree) and hard-requires a writable log/ dir — it exits 255
    # silently when it cannot open log/log.txt.
    chmod -R u+w "$DST/data" || true
    mkdir -p "$DST/log"
    if [ ! -e "$DST/iso" ]; then
      ln -s /Volumes/data/isos "$DST/iso"
    fi
  '';
in
{
  systemd.services.iventoy = {
    description = "iVentoy PXE boot server (ProxyDHCP for /Volumes/data/isos)";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      # Bundled libs resolve transitive deps (libglib -> bundled libiconv).
      LD_LIBRARY_PATH = "${iventoy}/share/iventoy/lib/lin64";
    };

    # iventoy.sh start daemonizes and exits; -R replays the saved PXE config
    # (no-op until the one-time web-UI setup above has been done).
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = "/srv/iventoy";
      ExecStart = "${pkgs.bash}/bin/bash /srv/iventoy/iventoy.sh -R start";
      ExecStop = "${pkgs.bash}/bin/bash /srv/iventoy/iventoy.sh stop";
      ExecStartPre = syncScript;

      # The unpatched iventoy binary expects /lib64/ld-linux-x86-64.so.2
      # (NixOS ships a non-functional stub there). Bind the real glibc lib64
      # over it in this unit's private mount namespace only.
      BindReadOnlyPaths = [
        "${pkgs.stdenv.cc.libc}/lib64:/lib64"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /srv/iventoy 0755 root root -"
  ];

  networking.firewall.allowedUDPPorts = [
    67 # DHCP proxy (ProxyNet mode)
    69 # TFTP
    4011 # ProxyDHCP
  ];
  networking.firewall.allowedTCPPorts = [
    16000 # PXE HTTP streaming
    26000 # Web management UI
  ];
}
