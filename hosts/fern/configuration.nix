# fern — HP 15 laptop (Ryzen 3 3250U) niri desktop.
#
# Hardware:
#   CPU:  AMD Ryzen 3 3250U (Picasso/Zen+, 2c/4t, 15 W)
#   GPU:  AMD Radeon Vega 3 iGPU (Mesa/radeonsi via amdgpu)
#   RAM:  8 GB DDR4
#   Disk: single SSD (disko: ESP + 8G swap + btrfs /root,/nix)
#
# Role:  Lightweight desktop mirroring scratch (NO Steam — deliberately
#        not imported): niri compositor with the DankMaterialShell
#        greeter (programs.dms-greeter), autoLogin straight into niri
#        as devji (globalModulesNixos chain → role:heim userland).
#        modules/profiles/laptop.nix adds auto-cpufreq (powersave on
#        battery, performance on AC) + libinput for the touchpad.
#
# Storage: persistent btrfs (no impermanence), monthly scrub below.
{ pkgs
, ...
}:
let
  user = import ../../modules/global/user.nix;
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/profiles/base-desktop-environment.nix
    ../../modules/profiles/laptop.nix
    ../../modules/profiles/base-node.nix
  ];

  networking.hostName = "fern";

  # --- Desktop (scratch-style): niri compositor + DMS greeter, no Steam ---
  # base-desktop-environment already enables autoLogin as devji; pin the
  # session to niri so autologin has an unambiguous target. The DMS
  # greeter module runs the resolved session; if it exits, greetd falls
  # back to the greeter login screen.
  services.displayManager.sddm = {
    enable = false;
    wayland.enable = true;
  };
  services.displayManager.defaultSession = "niri";
  programs.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = user.home; # Sync themes with user's DankMaterialShell config
  };

  # This unit's Ryzen 3 3250U reports unreliable RDRAND (the kernel logs
  # "RDRAND is not reliable on this platform; disabling"), so the
  # prebuilt Antigravity CLI aborts in BoringSSL's CRNGT self-test on
  # every invocation. OPENSSL_ia32cap=0 forces BoringSSL's portable
  # (no-asm) crypto paths, which sidesteps the broken RDRAND; wrap the
  # binary with it. Keep doInstallCheck=false since `agy --version`
  # still aborts in the build sandbox where the wrapper env may race
  # the self-test.
  nixpkgs.overlays = [
    (final: prev: {
      antigravity-cli = prev.antigravity-cli.overrideAttrs (old: {
        doInstallCheck = false;
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.makeWrapper ];
        postInstall = (old.postInstall or "") + ''
          wrapProgram "$out/bin/agy" --set OPENSSL_ia32cap "0:~0"
        '';
      });
    })
  ];

  # Vega 3 iGPU — Mesa/radeonsi; amdgpu drives it (modesetting by DRI3
  # under Wayland). Redistributable firmware covers the APU + laptop
  # WiFi/BT (HP 15 units ship Realtek/MediaTek/Intel cards).
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.graphics.enable = true;
  hardware.enableRedistributableFirmware = true;

  # --- Btrfs auto-scrub (monthly) ---
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  environment.systemPackages = with pkgs; [
    btop # system monitor
  ];

  system.stateVersion = "26.05";
}
