# OpenWrt / FRITZ!Box 7320 control shell: profile switching, capture and survey
# against the box, without installing anything on its 3.6 MB of free flash.
{
  pkgs,
  root ? null,
}: let
  inherit (pkgs) lib;
  tools = [
    pkgs.openssh
    pkgs.sops
    pkgs.age
    pkgs.whois # mkpasswd, for `openwrt set-password`
    pkgs.curl
    pkgs.jq
    pkgs.coreutils
    pkgs.util-linux # setsid, for the password fallback
  ];
  # Not writeShellApplication: its shellcheck gate would fail the build over
  # style findings in a script whose job is calling ssh.
  openwrt =
    pkgs.runCommandLocal "openwrt" {
      nativeBuildInputs = [pkgs.makeWrapper];
    } ''
      install -Dm755 ${root + "/scripts/openwrt/openwrt.sh"} $out/bin/openwrt
      wrapProgram $out/bin/openwrt --prefix PATH : ${lib.makeBinPath tools}
    '';
in
  pkgs.mkShell {
    packages =
      [
        openwrt
        pkgs.tcpdump # the copy used for remote streaming, and locally
        pkgs.horst # 2.4 GHz survey, 140 KiB on the box
        pkgs.hcxdumptool # PMKID/handshake capture
        pkgs.aircrack-ng # suite, 1.7 MB — side-load only when needed
        pkgs.nmap # 12 MB: never fits the router, run it from here
        pkgs.socat
        pkgs.python3
        pkgs.iproute2
        pkgs.netcat
      ]
      ++ tools;

    shellHook = ''
      # The wrapper needs the working tree for modules/secrets.yaml (a store
      # copy of a secret you just edited is the stale one) and for netprofile.
      export OPENWRT_REPO="''${OPENWRT_REPO:-$PWD}"
      export OPENWRT_NETPROFILE="''${OPENWRT_NETPROFILE:-${root}/scripts/openwrt/netprofile.sh}"
      echo "OpenWrt 7320 — 'openwrt status', 'openwrt profile monitor', 'openwrt install'"
      if [[ $- == *i* ]]; then
        if openwrt status >/dev/null 2>&1; then
          if openwrt tunnel up >/dev/null 2>&1; then
            echo "  forwarded: luci http://127.0.0.1:8081 · ssh 127.0.0.1:2222 · socks 127.0.0.1:1080"
            # Close the forwards with the shell instead of leaving a listener
            # behind for ControlPersist's 10 minutes.
            trap 'openwrt tunnel down >/dev/null 2>&1 || true' EXIT
          fi
        else
          echo "  router unreachable — set OPENWRT_JUMP=<user@jumphost>"
        fi
      fi
    '';
  }
