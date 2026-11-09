# Hardware acceleration for i5-8250U (Kaby Lake R, Intel UHD Graphics 620).
{
  config,
  pkgs,
  ...
}: let
  user = import ../../modules/global/user.nix;
  netbookIp = config.fleet.inventory.hosts.netbook.network.lan_ip;
in {
  # --- Intel QuickSync VA-API ---
  nixpkgs.config.packageOverrides = pkgs: {
    intel-vaapi-driver = pkgs.intel-vaapi-driver.override {enableHybridCodec = true;};
  };

  hardware.graphics = {
    enable = true;
    # This box is a NAS/media server with an Intel iGPU — no Steam, no Wine,
    # no 32-bit games. Leaving the base-desktop default (true on x86_64) pulls
    # a second mesa AND a second llvm-21.1.8-lib for graphics-drivers-32bit:
    # measured 2026-10-17 at ~812 MiB of the frieren closure. A plain value
    # beats the profile's `lib.mkDefault`.
    enable32Bit = false;
    extraPackages = with pkgs; [
      intel-media-driver # iHD — modern QuickSync driver
      intel-vaapi-driver # i965 — legacy VA-API backend (hybrid codecs)
      libva-vdpau-driver # VDPAU → VA-API bridge
      vpl-gpu-rt # oneVPL runtime (Gen9+, H.264/HEVC/H.265)
      intel-compute-runtime-legacy1 # OpenCL legacy (correct for Gen8-Gen11 i.e. KBL)
    ];
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  # --- Dell D6000 Universal Dock: desktop-only ---
  # Enabled by `specialisation.desktop`, so the headless boot carries neither
  # evdi nor the DisplayLink daemon.

  # --- Power management (laptop-as-server, battery = built-in UPS) ---
  # powertop is intentionally NOT enabled: its `--auto-tune` boot service
  # enables USB autosuspend, which kills the Intel combo Bluetooth adapter
  # (the classic powertop BT-killer) — frieren needs reliable BT input for
  # the TV keyboard/mouse. `powerManagement.enable = true` (configuration.nix)
  # already handles CPU frequency scaling. Re-add powertop only if you also
  # add a udev rule exempting the BT USB device from autosuspend.

  # D.4.0: Graceful shutdown on low battery (~5%).
  # frieren is a laptop-as-server; its battery acts as a built-in UPS.
  # When mains power is lost and the battery drops to 5%, UPower triggers
  # a clean poweroff (systemctl poweroff), gracefully unmounting Btrfs
  # and stopping services before power is completely lost.
  services.upower = {
    enable = true;
    usePercentageForPolicy = true;
    percentageLow = 15;
    percentageCritical = 8;
    percentageAction = 5;
    criticalPowerAction = "PowerOff";
  };

  # The battery is the UPS, so a mains cut ends in a poweroff at 5% (UPower).
  # This fires at 7% first: notify alice's netbook, wait 60 s, then power off
  # unless mains came back. UPower's 5% action stays as the backstop.
  systemd.services.frieren-battery-notice = {
    description = "Warn alice@netbook that frieren is on battery, then power off";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "frieren-battery-notice" ''
        set -euo pipefail
        cat=${pkgs.coreutils}/bin/cat
        bat=/sys/class/power_supply/BAT0
        state=/run/frieren-battery-notice.fired
        [ -r "$bat/capacity" ] || exit 0
        cap=$($cat "$bat/capacity")
        [ "$($cat "$bat/status")" = Discharging ] || exit 0
        [ "$cap" -le 7 ] || exit 0
        [ -e "$state" ] && exit 0
        : > "$state"
        trap 'rm -f "$state"' EXIT
        ${pkgs.util-linux}/bin/runuser -u ${user.name} -- \
          ${pkgs.coreutils}/bin/env HOME=${config.users.users.${user.name}.home} \
          ${pkgs.openssh}/bin/ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
            -o ConnectTimeout=10 alice@${netbookIp} \
            "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$(id -u)/bus notify-send -u critical -a frieren 'frieren: battery low' 'Mains power is out and frieren is at ''${cap}%. Plug it back in: it powers off in 60 s.'" \
          || echo "frieren-battery-notice: alice@${netbookIp} unreachable" >&2
        ${pkgs.coreutils}/bin/sleep 60
        [ "$($cat "$bat/status")" = Discharging ] || { echo "frieren-battery-notice: mains restored, staying up"; exit 0; }
        ${pkgs.systemd}/bin/systemctl poweroff
      '';
    };
  };

  systemd.timers.frieren-battery-notice = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "1min";
    };
  };

  # --- TPM 2.0 (Intel PTT hardware cryptoprocessor) ---
  security.tpm2 = {
    enable = true;
    tctiEnvironment.enable = true;
  };

  # Allow devji direct access to the TPM resource manager (/dev/tpmrm0)
  users.users.devji.extraGroups = ["tss"];

  environment.systemPackages = with pkgs; [
    age-plugin-tpm
    tpm2-tools
  ];
}
