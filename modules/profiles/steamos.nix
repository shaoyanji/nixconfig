# SteamOS-style kiosk profile for headless Steam clients.
#
# Composes:
#   - programs.steam (imported from ./steam.nix)
#   - a kiosk-session wrapper (`cage + steam -gamepadui`) installed
#     unconditionally via pkgs.writeShellScriptBin. Replaces the round-3
#     gamescope-bypass wrapper because Steam Big Picture's PATH-detected
#     gamescope launcher kept re-launching pkgs.gamescope (which crashes
#     on Kepler+legacy_580). The wrapper binary name remains
#     `gamescope-session` so greetd's --cmd resolution stays unchanged.
#   - pkgs.cage (wlroots-based Wayland kiosk compositor). Opens
#     /dev/dri/card0 via the nvidia_drm KMS stack that round 2 already
#     wired up; does NOT require Vulkan for compositing. Steam runs as
#     a Wayland CLIENT under cage (XWayland native); this bypasses
#     Steam's embedded-compositor fallback that produced the
#     `Creating headless backend` log line.
#   - PipeWire audio (mandatory for game audio)
#   - greetd auto-login as devji into gamescope-session (no login prompt)
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
    # Kepler / legacy_580 path (round 5):
    #
    # Why we cannot stay on rounds 1-4: Steam Big Picture's
    # PATH-detected gamescope launcher (a Steam internal heuristic, not
    # the upstream-program-gamescopeSession desktop file) keeps finding
    # `pkgs.gamescope` in PATH and re-launching it as a child. gamescope's
    # wlserver then logs `Creating headless backend` and crashes because
    # the legacy_580 Vulkan ICD is incomplete (no
    # VK_KHR_image_drm_format_modifier) - even with nvidia_drm KMS up
    # from round 2.
    #
    # Round-5 fix: drop `pkgs.gamescope` from the closure entirely (this
    # profile) and use `cage` - a wlroots-based Wayland kiosk compositor
    # that opens /dev/dri/card0 via nvidia_drm KMS WITHOUT requiring
    # Vulkan for the compositor side (only mesa GL is needed).
    #
    # After this wrapper fires:
    #   1. greetd's --cmd gamescope-session resolves via PATH to *this*
    #      script. The upstream-generated gamescope-session script
    #      (auto-installed by programs.steam.gamescopeSession.enable=true
    #      in modules/profiles/steam.nix) is suppressed by a host-scoped
    #      mkForce in hosts/kellerbench/configuration.nix so PATH always
    #      hits us first.
    #   2. cage -s starts, opens DRM/KMS on /dev/dri/card0, brings up a
    #      wlroots Wayland server (wayland-0).
    #   3. Steam -gamepadui runs as the single fullscreen Wayland app
    #      under cage (Steam is XWayland-native; cage forwards it to
    #      Wayland). Steam's own embedded-compositor fallback is bypassed
    #      and the headless-backend wlroots fallback never fires.
    #
    # The `-s` flag on cage tells cage NOT to exit when Steam forks
    # background helpers (SteamUpdate, SteamWebHelper); without `-s`
    # cage would exit as soon as Steam's initial process forks.
    #
    # Fallback (round 6, if cage also fails): drop the wrapper
    # entirely and run steam under X11 via `${pkgs.xorg.xinit}/bin/xinit
    # "${pkgs.steam}/bin/steam -gamepadui" -- :0 vt1 -nolisten tcp` -
    # services.xserver.enable = true is already set on kellerbench.
    #
    # Future Turing/Ampere/Blackwell successor with a modern Vulkan
    # ICD: swap cage for gamescope, flipping the exec line below to
    # `exec ${pkgs.gamescope}/bin/gamescope -e -- steam -gamepadui`
    # AND restoring `programs.gamescope.enable = true` in this profile
    # AND removing the host-scoped mkForce in
    # hosts/kellerbench/configuration.nix.
    set -eu
    log=/tmp/gamescope-session.log
    {
      echo "=== gamescope-session (cage-based) wrapper start $(date -Iseconds) ==="
      echo "    USER=$(id -un) UID=$(id -u)"
      echo "    WAYLAND_DISPLAY=''${WAYLAND_DISPLAY:-<unset>}"
      echo "    XDG_SESSION_TYPE=''${XDG_SESSION_TYPE:-<unset>}"
      echo "    DISPLAY=''${DISPLAY:-<unset>}"
      echo "    Cage binary: ${pkgs.cage}/bin/cage"
      echo "    Steam binary: ${pkgs.steam}/bin/steam"
    } >>"$log" 2>&1
    if [ ! -x ${pkgs.cage}/bin/cage ]; then
      echo "    FATAL: cage binary missing or not executable" >>"$log"
      exit 127
    fi
    if [ ! -x ${pkgs.steam}/bin/steam ]; then
      echo "    FATAL: steam binary missing or not executable" >>"$log"
      exit 127
    fi
    echo "    exec ${pkgs.cage}/bin/cage -s -- ${pkgs.steam}/bin/steam -gamepadui" >>"$log"
    exec ${pkgs.cage}/bin/cage -s -- ${pkgs.steam}/bin/steam -gamepadui
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

  # gamescope package is intentionally NOT installed on this Kepler
  # profile (round 5). Cage is the Wayland kiosk compositor for Steam
  # (-gamepadui). Removing pkgs.gamescope:
  #   - prevents Steam Big Picture's PATH-detected gamescope-launcher
  #     heuristic from finding the binary and re-forking it (this was
  #     the cause of the `Creating headless backend` regression the
  #     user reported after round 4). Steam cannot fork gamescope if
  #     gamescope is not in the closure;
  #   - slims the closure by ~50MB;
  #   - eliminates the wlroots-keepalive error Steam was producing.
  # Future Turing/Ampere/Blackwell successors with a modern Vulkan ICD
  # can flip this back to `true` AND update the wrapper body in the
  # `let` block above to
  # `exec ${pkgs.gamescope}/bin/gamescope -e -- steam -gamepadui`
  # AND remove the host-scoped mkForce in
  # hosts/kellerbench/configuration.nix.
  programs.gamescope.enable = false;

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

  # Auto-login directly into gamescope-session as devji. greetd runs
  # default_session as the target user without showing a login prompt
  # when user+command are both set, eliminating the tuigreet step
  # entirely. After the Steam Big Picture session exits (or cage exits),
  # greetd re-launches the same session, giving permanent auto-login
  # behavior. To enable a tuigreet-based manual login instead, restore
  # the user = "greeter" line + the
  # ${pkgs.tuigreet}/bin/tuigreet --time --cmd gamescope-session command
  # AND re-add the users.users.greeter/users.groups.greeter blocks below
  # (kept commented as toggles for future re-enable).
  services.greetd = {
    enable = true;
    settings.default_session = {
      user = "devji";
      command = "gamescope-session";
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

  # Disabled-block (autologin mode skips the tuigreet greeter; preserve
  # as dormant toggle for future re-enable):
  # users.users.greeter = {
  #   isSystemUser = true;
  #   group = "greeter";
  #   home = "/var/empty";
  #   description = "greetd greeter user";
  # };
  # users.groups.greeter = { };
}
