# SteamOS-style kiosk profile for headless Steam clients.
#
# Composes:
#   - programs.steam (imported from ./steam.nix)
#   - a gamescope-session wrapper auto-synthesized in this profile via
#     pkgs.writeShellScriptBin (installed unconditionally; wins over any
#     upstream-generated gamescope-session script when the host also disables
#     programs.steam.gamescopeSession - kellerbench does this in its host
#     config, see hosts/kellerbench/configuration.nix)
#   - PipeWire audio (mandatory for game audio)
#   - greetd + tuigreet login that drops the user into gamescope-session
#   - Avahi / mDNS for LAN game discovery + local network transfers
#   - 32-bit graphics packages for legacy OpenGL games
#   - All Steam network services (remotePlay, dedicatedServer,
#     localNetworkGameTransfers) — full remote play + LAN posture
#
# Designed for hosts using globalModulesContainers (noDE) so no dms, niri,
# KDE, or GNOME desktop modules leak into the closure.
#
# Usage:
#   imports = [ ../../modules/profiles/steamos.nix ];
{ config
, lib
, pkgs
, ...
}:
let
  # Synthesize the gamescope-session wrapper that greetd will exec. The wrapper
  # is installed unconditionally in environment.systemPackages below so it
  # ALWAYS wins the PATH lookup. Whether the wrapper actually calls gamescope
  # vs Steam's `-gamepadui` directly is decided inside the wrapper, gated on
  # the host's graphics stack (Kepler + legacy_580 forces the bypass; future
  # Turing / Ampere / Blackwell successors can flip back to gamescope here).
  #
  # Caveat: gamescope 3.16+ strictly requires Vulkan for its compositor
  # (no real OpenGL fallback). On NVIDIA Kepler with the legacy_580
  # driver the Vulkan ICD exposes fewer features than gamescope prefers —
  # gamescope will log "incomplete Vulkan" warnings and try to fall back
  # where it can, but compositing may still fail. The `exec steam -gamepadui`
  # line below is the Kepler bypass. Restoring `exec gamescope -e -- steam -gamepadui`
  # re-opts in to gamescope compositing on successor hardware.
  customGamescopeSession = pkgs.writeShellScriptBin "gamescope-session" ''
    # Kepler / legacy_580 path: gamescope wlserver fails with
    # `Creating headless backend` because the Vulkan ICD is incomplete
    # (no VK_KHR_image_drm_format_modifier). Bypass gamescope entirely
    # and launch Steam Big Picture directly. After this wrapper fires:
    #   - greetd's --cmd gamescope-session resolves via PATH to *this* script.
    #     The upstream-generated gamescope-session script (auto-installed by
    #     programs.steam.gamescopeSession.enable=true in steam.nix) is
    #     suppressed by a host-scoped mkForce in hosts/kellerbench/configuration.nix,
    #     so PATH always hits us first.
    #   - Steam Big Picture starts on top of services.xserver (XWayland
    #     fallback if no native Wayland compositor is running).
    # Future Kepler successor (Ampere / Blackwell): flip the wrapper body
    # back to `exec ${pkgs.gamescope}/bin/gamescope -e -- steam -gamepadui`
    # AND remove the host-scoped mkForce so upstream's gamescopeSession
    # desktop entry returns.
    set -eu
    log=/tmp/gamescope-session.log
    {
      echo "=== gamescope-session wrapper start $(date -Iseconds) ==="
      echo "    USER=$(id -un) UID=$(id -u)"
      echo "    WAYLAND_DISPLAY=''${WAYLAND_DISPLAY:-<unset>}"
      echo "    XDG_SESSION_TYPE=''${XDG_SESSION_TYPE:-<unset>}"
      echo "    DISPLAY=''${DISPLAY:-<unset>}"
      echo "    Steam binary: ${pkgs.steam}/bin/steam"
    } >>"$log" 2>&1
    if [ ! -x ${pkgs.steam}/bin/steam ]; then
      # No TTY-side UX for a 5s pause, so exit loudly and let the operator
      # inspect /tmp/gamescope-session.log from another session.
      echo "    FATAL: steam binary missing or not executable" >>"$log"
      exit 127
    fi
    echo "    exec ${pkgs.steam}/bin/steam -gamepadui" >>"$log"
    exec ${pkgs.steam}/bin/steam -gamepadui
  '';
in
{
  imports = [
    ./steam.nix
  ];

  # Surface our wrapper unconditionally so /run/current-system/sw/bin/gamescope-session
  # is always resolvable from PATH. Without the upstream `lib.optionals (!(pkgs ? gamescope-session))`
  # guard, the upstream-generated gamescope-session (from `programs.steam.gamescopeSession.enable`
  # in steam.nix) would shadow ours - that upstream script calls the real
  # gamescope binary which segfaults on Kepler + legacy_580. We pair this with
  # the `programs.steam.gamescopeSession.enable = lib.mkForce false` override
  # below so Steam's NixOS module stops generating that competing wrapper.
  environment.systemPackages = [ customGamescopeSession ];

  # gamescope binary is intentionally still installed (~50MB closure cost)
  # so a future Kepler successor (Ampere / Blackwell) with a proper Vulkan
  # ICD can re-opt-in to gamescope by flipping customGamescopeSession in
  # this profile. Not removing it on this Kepler box keeps the door open
  # for hardware upgrades without a profile rewrite.
  programs.gamescope.enable = true;

  # Note: `programs.steam.gamescopeSession.enable` is NOT overridden here.
  # That option (set to `true` in modules/profiles/steam.nix) generates a
  # NixOS-module-level `gamescope-session` script that shadows our wrapper
  # in PATH on kellerbench (Kepler + legacy_580) - causing gamescope to be
  # called and segfault. The override lives in
  # `hosts/kellerbench/configuration.nix` (host-scoped) so that any future
  # host importing this profile on Turing-class GPUs keeps the upstream
  # gamescopeSession feature available. See commit log for rationale.

  # 32-bit graphics packages for legacy OpenGL Steam games. mkForce so
  # this wins over GPU modules (e.g. amd-rx-5700-xt sets enable32Bit=false).
  hardware.graphics.enable32Bit = lib.mkForce true;

  # Audio stack — required for game audio on a Steam-only box.
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  services.pulseaudio.enable = false;

  # LAN discovery for Steam local game transfers / broadcasts.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  # seatd: libseat backend for gamescope's wlroots-based wlserver.
  # Without an enabled seatd, libseat falls through to systemd-logind
  # or builtin, which intermittently fails to acquire a seat under
  # greetd-launched Wayland sessions. The user-reported symptom is
  # `wlserver: libseat backend ...` and gamescope never comes up, so
  # the user lands back on the kernel TTY.
  services.seatd.enable = true;

  # greetd + tuigreet: minimalist console-only login that drops the user
  # directly into gamescope-session (Steam Big Picture). Exiting Big
  # Picture returns the user to tuigreet.
  services.greetd = {
    enable = true;
    settings.default_session = {
      # tuigreet auto-discovers wayland-sessions; --cmd runs after login.
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd gamescope-session";
      user = "greeter";
    };
  };

  # GPU + seatd device access — gamescope, Steam, and any XWayland app needs to open
  # /dev/dri/renderD* (render group), /dev/dri/card0 (video group), /dev/input/event*
  # (input group), and the seatd socket at /run/seatd.sock (seat group).
  # base-node.nix sets wheel + networkmanager; desktop-client.nix layers docker + video.
  # Steam-only hosts don't import desktop-client, so we add these here.
  # `seat` group is required so devji can talk to libseat once greetd has
  # switched away from the `greeter` user to run gamescope-session.
  users.users.devji.extraGroups = [ "video" "render" "input" "seat" ];

  users.users.greeter = {
    isSystemUser = true;
    group = "greeter";
    home = "/var/empty";
    description = "greetd greeter user";
  };
  users.groups.greeter = { };
}
