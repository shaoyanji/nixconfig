# eisen — Xeon E5-2673 v3 + RX 5700 + 64 GB RAM gaming desktop.
# Runbook and measurements: .agents/deploy/hosts/eisen.md; the GPU verdicts live in
# notes eisen-llm-stack and open-eisen-gpu-off-bus.
{
  self,
  pkgs,
  user,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./amd-rx-5700.nix
    self.modules."services.fleet-sentinel"
    self.modules."profiles.sentinel-push"
    # Gamescope-only kiosk: greetd auto-logs devji into `steam-gamescope`, so
    # Steam Big Picture is the entire UI — the same shape as ares and
    # deckstation. profiles.steamos brings profiles.steam with it. The desktop
    # shell (Dux on niri, and the Ryoku tier before it) is gone: it spent
    # ~450–500 MiB of VRAM and several GiB of RAM the model wants, and this host
    # is a console.
    self.modules."profiles.steamos"
    self.modules."profiles.base-node"
    self.modules."profiles.nas-client"
    self.modules."profiles.sunshine"
    self.modules."services.qwen-tts"
    self.modules."services.llm-decision-router"
    self.modules."profiles.dns-client"
    ./llm-server.nix
    ./parakeet.nix
    ./decision-models.nix
    ./qwen-image.nix
    ./strata.nix
  ];

  # --- Session: gamescope kiosk, no desktop ---
  # Boot lands straight in Steam Big Picture under gamescope-session, so Steam
  # Link / Moonlight work with zero interaction after power-on; a logout returns
  # to greetd, which relaunches the same session. There is no desktop shell and
  # no login screen: profile.steamos sets greetd's `default_session` to
  # `steam-gamescope`.

  # Kept because it is a validated value (nixpkgs asserts the name is a session
  # Steam provides at the priority it is set); greetd ignores it and autologins
  # from `default_session` instead.
  services.displayManager.defaultSession = "steam";
  programs.dms-greeter.enable = false;

  # X server for XWayland: Steam spawns legacy X11-only windows inside
  # gamescope's Wayland surface.
  services.xserver.enable = true;

  # --- Steam under gamescope ---
  # The RX 5700's modern Vulkan ICD fully supports gamescope's compositor
  # (unlike kellerbench's Kepler + legacy_580 card, where gamescope's
  # wlserver crashes with "Creating headless backend").  steam.nix enables
  # programs.steam.gamescopeSession, and profile.steamos points greetd at the
  # `steam-gamescope` wrapper so the whole session is one unit.
  programs.gamescope.enable = true;
  programs.steam.gamescopeSession.args = [
    "-W"
    "1920"
    "-H"
    "1080"
    "-w"
    "1920"
    "-h"
    "1080"
    "-r"
    "60"
    "-O"
    "HDMI-A-1"
  ];

  # --- Boot persona: gaming desktop by default, inference server on demand ---
  # This file is the boot default (gamescope kiosk). `specialisation.server`
  # (server.nix) is the TTY-only persona: no greeter, no compositor, no Steam,
  # nothing competing with the model for the card. It ships in the same generation, so
  # the systemd-boot menu has it and `nixos-rebuild switch --specialisation
  # server` reaches it without rebuilding.
  specialisation.server.configuration = {
    imports = [./server.nix];
  };

  # --- Bluetooth (wireless controllers in Steam) ---
  hardware.bluetooth.enable = true;

  # Local builds are legitimate on this host (12c/24t, "Heavy parallel
  # multi-threaded builds" in inventory), but 24 concurrent C++ compiles on a
  # 62 GiB box OOM-kill the desktop session. Cap the daemon and leave headroom
  # for greetd/gamescope and a loaded LLM model.
  nix.settings.max-jobs = 8;

  # --- Tailscale mesh networking ---
  # Enables the eisen host on the tailnet so Moonlight clients can stream
  # from outside the LAN (via Tailscale IPs / MagicDNS).  Routing features
  # are set to "both" so eisen can act as an exit node and subnet router
  # if needed later.  DNS through the pi-hole at frieren (100.97.61.65)
  # keeps ad-blocking consistent across the tailnet.
  fleet.tailscale = {
    clientPolicy = true;
    acceptDns = false;
    acceptRoutes = false;
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
    # eisen is physically on 192.168.3.0/24 (LAN). Accepting the tailnet's
    # advertised 192.168.3.0/24 subnet route causes table 52 to hijack all
    # direct LAN traffic (e.g. Steam Link at 192.168.3.48), breaking local streaming.
  };

  # profiles.dnsClient: resolved queries the whole list in parallel — ads best-effort.
  profiles.dnsClient.enable = true;

  # --- Wake-on-LAN (WOL) ---
  # udevd arms linkConfig.WakeOnLan = "magic" on enp9s0 (Realtek GbE, MAC
  # 00:e0:22:1c:bb:ed) at every boot, so the NIC listens in standby and
  # `task infra:wol:eisen` can start the box from S5. Kept deliberate: any host on
  # the LAN can wake it, so a device that emits magic packets on its own is the
  # thing to fix — the Steam Link's saved-host list is where that comes from.
  networking.interfaces.enp9s0.wakeOnLan.enable = true;

  # --- 4K transcoding tooling ---
  # ffmpeg-full is in amd-rx-5700.nix for VAAPI-accelerated encode/decode.
  # When Jellyfin is deployed, add jellyfin-ffmpeg for its bundled codecs.
  environment.systemPackages = with pkgs; [
    libva-utils # vainfo — check VCN encode/decode surface list
    jq # JSON wrangling
    htop # system monitor
    btop # prettier system monitor
    ethtool # NIC diagnostics and WOL verification
    aider-chat # AI pair programming terminal CLI
  ];

  # --- LLM and Decision Model Router (SubZeroClaw / Jev bridge) ---
  services.llm-decision-router = {
    enable = true;
    port = 8000;
    # Kolibri is dormant (patched fork, retired 2026-10-19); Qwen is the only
    # model llama-swap serves, so it is also the router default.
    defaultModel = "qwen3.6-35b-a3b";
  };

  # --- Storage drives ---
  #
  # /mnt/steam: sda — 931.5G HDD (formerly the Proxmox install), formatted
  # as a single btrfs partition labeled `steam` (btrfs+zstd).  Mounted
  # by-label so no UUID needs tracking, with `nofail` so a missing label
  # never blocks boot into emergency mode.  After first mount, own it once:
  #   sudo chown devji:users /mnt/steam
  # Then add it in Steam: Settings → Storage → Add Drive → /mnt/steam.
  #
  # /mnt/media (FUTURE): 16 TB HDD → media library.  When the drive
  # arrives: mkfs.btrfs -L media /dev/sdX, then uncomment the block
  # below and add it to autoScrub.
  #
  # fileSystems."/mnt/media" = {
  #   device = "/dev/disk/by-label/media";
  #   fsType = "btrfs";
  #   options = [ "compress=zstd" "noatime" "autodefrag" ];
  # };
  # Home: docs/steam-cache.md §"Layout" and §"One-time setup".

  fileSystems."/mnt/steam" = {
    device = "/dev/disk/by-label/steam";
    fsType = "btrfs";
    options = ["compress=zstd" "noatime" "autodefrag" "nofail"];
  };

  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-label/storage";
    fsType = "btrfs";
    options = ["compress=zstd" "noatime" "autodefrag" "nofail"];
  };

  # tmpfs shadercache dir.  The /mnt/steam mountpoint is created by the
  # mount unit itself; ownership is set once via chown after first mount.
  systemd.tmpfiles.rules = [
    "d ${user.home}/.steam/steam/steamapps/shadercache 0755 devji users - -"
  ];

  # --- Btrfs auto-scrub (monthly) ---
  # The NVMe root and the Steam library are btrfs.  Monthly scrub
  # detects and repairs bit rot using checksums.  Add /mnt/media when
  # that drive is provisioned.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [
      "/"
      "/mnt/steam"
    ];
  };

  # --- Steam shader cache on tmpfs (16 GB RAM disk) ---
  # Dota 2 and other Vulkan/OpenGL titles compile shaders on first launch.
  # Keeping the cache in RAM eliminates NVMe wear and reduces stutter from
  # shader compilation during gameplay.  16 GB leaves 48 GB for page cache
  # and active game data — more than enough for any single game.
  fileSystems."${user.home}/.steam/steam/steamapps/shadercache" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=16G"
      "mode=0755"
      "uid=1000"
      "gid=100"
    ];
  };

  # --- Offline Qwen3-TTS speech (OpenAI-compatible /v1/audio/speech) ---
  # Built from source with a Vulkan backend (Navi 10 has no ROCm target).
  # Weights on the data array; exposed as tts.lan (nginx :80) and tailscale
  # serve :8444. See modules/services/qwen-tts.nix and hosts/eisen/TTS.md.
  services.qwen-tts = {
    enable = true;
    port = 8181;
    modelDir = "/mnt/storage/tts/models";
    model = "qwen-talker-1.7b-customvoice-Q4_K_M.gguf";
    codec = "qwen-tokenizer-12hz-Q8_0.gguf";
    voice = "vivian";
  };

  services.fleetSentinel = {
    enable = true;
    watchUnits = [
      {unit = "nixos-upgrade.service";}
      {unit = "tailscaled.service";}
    ];
  };

  services.openssh.enable = true;
  system.stateVersion = "25.05";
}
