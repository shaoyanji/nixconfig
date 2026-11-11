# Alice's travel netbook — fleet nixpkgs, LTS kernel (newer initrds could not
# mount this eMMC root), no global chain, deployed by push. Rationale and the
# boot test: `.agents/deploy/hosts/netbook.md`.
{
  self,
  lib,
  pkgs,
  ...
}: let
  # The fleet's deploy key (frieren's `devji` identity). alice logs in with it,
  # and root accepts the same key so `nix copy --to ssh://root@…` can push a
  # closure over the LAN — `PermitRootLogin` stays `prohibit-password`, so this
  # grants keys only. One literal, used twice.
  deployKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHnNR7isgO8VDY76XzwyH3mOg1/DQo8dZgqQOfziw0DQ devji@nixos";
  # The wallpaper: a hash-pinned store path, so the background is there before
  # the NAS mounts and survives a reorganised ~/Pictures. A newer plate is a
  # one-line URL + hash change; the bank's manifest is published/urls.tsv.
  # A scene rather than a character portrait: `swaybg -m fill` crops to
  # 1024x600, and a cropped face on a panel this small reads as a mistake.
  fjordWallpaper = pkgs.fetchurl {
    url = "https://res.cloudinary.com/de1eajx01/image/upload/assets/wall/2026-11-10/fjord.png";
    sha256 = "1ypnr30mgx6fbs6xwy7hxifzw1x05sfiwxpf0zl6adqqfswq2qgv";
  };

  # The characters this keyboard's broken ribbon connector lost, and the living
  # key each one is rented from. One list, two projections: the dwl chords
  # spliced into the keymap, and the card `Mod+Shift+grave` shows. `p` is a lost
  # letter rather than punctuation and is a row like the rest.
  deadKeys = [
    {
      key = "s";
      plain = "/";
      shifted = "?";
    }
    {
      key = "n";
      plain = "-";
      shifted = "_";
    }
    {
      key = "z";
      plain = "0";
      shifted = ")";
    }
    {
      key = "m";
      plain = ";";
      shifted = ":";
    }
    {
      key = "b";
      plain = "\\";
      shifted = "|";
    }
    {
      key = "u";
      plain = "=";
      shifted = "+";
    }
    {
      key = "c";
      plain = "[";
      shifted = "{";
    }
    {
      key = "o";
      plain = "]";
      shifted = "}";
    }
    {
      key = "g";
      plain = "(";
      shifted = ")";
    }
    {
      key = "v";
      plain = "`";
      shifted = "~";
    }
    {
      key = "y";
      plain = "p";
      shifted = "P";
    }
    {
      key = "x";
      plain = "'";
      shifted = "\"";
    }
  ];

  # A shell-quoted word for one character, then the C literal that carries it
  # into the keymap. The apostrophe cannot sit inside single quotes, and a
  # backslash or a double quote has to survive C as well as sh.
  shellWord = c:
    if c == "'"
    then ''"'"''
    else "'${c}'";
  cString = c: let
    escaped = builtins.replaceStrings ["\\" "\""] ["\\\\" "\\\""] (shellWord c);
  in ''"${escaped}"'';

  deadKeyRows =
    lib.concatMapStrings (d: ''
      TYPED(${d.key}, MODKEY, ${cString d.plain}),
      TYPED(${d.key}, MODKEY | WLR_MODIFIER_SHIFT, ${cString d.shifted}),
    '')
    deadKeys;

  # The same list as a cheat sheet. Three keys per line keeps the card inside
  # fnott's 240 px body instead of truncating the rows that matter.
  deadKeyCells = map (d: "${d.key} ${d.plain}${d.shifted}") deadKeys;
  keyTable = lib.concatStringsSep "\n" (
    ["Dead keys: the key, then plain (Mod) and shifted (Mod+Shift)"]
    ++ builtins.genList
    (i: lib.concatStringsSep "   " (lib.take 3 (lib.drop (i * 3) deadKeyCells)))
    (builtins.div (builtins.length deadKeyCells + 2) 3)
    ++ ["Vim :wq = Mod+Shift+m, w, q"]
  );

  keysCard = pkgs.writeShellScriptBin "netbook-keys" ''
    table=${lib.escapeShellArg keyTable}
    if [ "''${1:-}" = --text ]; then
      printf '%s\n' "$table"
      exit 0
    fi
    # fnott owns org.freedesktop.Notifications here; a timeout of 0 means "do not
    # expire", so the card stays until it is dismissed.
    busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications \
      org.freedesktop.Notifications Notify susssasa{sv}i \
      netbook-keys 0 "" "Dead keys" "$table" 0 0 0
  '';
in {
  users.users.root.openssh.authorizedKeys.keys = [deployKey];
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # Shared profiles instead of copies. `boot.nix` owns the loader switches —
    # this box's firmware variables are read-only, so it opts out through the
    # profile's own option rather than hand-rolling `systemd-boot.enable`.
    # `nas-client.nix` owns /Volumes/data: LAN first, tailnet fallback, a
    # recovery timer and the gc-root guard — strictly more than the two-line
    # fstab entry it replaces, and what a travel laptop actually needs.
    self.modules."profiles.boot"
    # The dwl session: keybinds, launcher, wallpaper, idle/lock. This host
    # ran niri, whose stock config was what it got — no fleet keybinds, and a
    # compositor sized for a desktop rather than for 2 GB and a Celeron.
    self.modules."profiles.dwl-desktop"
    self.modules."profiles.nas-client"
    # Voice dictation as a packaged script: the body is shellcheck-gated at
    # build and the Groq key is decrypted from the fleet sops plane at use time
    # with this host's TPM identity, instead of a plaintext file in $HOME.
    self.modules."profiles.voice-dictate"
  ];

  profiles.boot.efi = false;

  boot.supportedFilesystems = ["f2fs" "nfs"];
  hardware.enableRedistributableFirmware = true;
  # Three is one more than this host has ever needed at once, and the menu is
  # 3 s — every extra generation is another 6.7 GiB closure to keep alive on an
  # eMMC that has already sat at 84 % once.
  boot.loader.systemd-boot.configurationLimit = 3;
  # Measured 2026-10-22: 13.1 s of a 47.3 s boot was the loader stage, 5 s of it
  # this countdown. 3 s keeps a usable window for the other generations while
  # still paying 2 s less than the default.
  boot.loader.timeout = 3;

  # eMMC has no seek cost, so the block-layer scheduler only adds latency; the
  # kernel recommends none for devices with their own queueing.
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="mmcblk*", ATTR{queue/scheduler}="none"
  '';
  services.fstrim.enable = true;
  services.tailscale.enable = true;

  # Out of the boot transaction: this host has no gcroots under /Volumes/data
  # (`nix-store --gc --print-roots`), so GC's root guard has nothing to protect
  # and every boot was paying a NAS probe. Clearing `wantedBy` is what empties
  # the unit's [Install] section; nix-gc's own `Wants=`/`After=` still pulls it
  # once the mount is up. The timer and the NM dispatcher are untouched.
  systemd.services.nix-gc.wants = lib.mkForce [];
  systemd.services.nas-path-governor.wantedBy = lib.mkForce [];

  # NetworkManager-wait-online stays enabled on purpose. Masking it on
  # 2026-10-22 looked like a 1.895 s win but only moved the wait: nas-path-governor
  # is WantedBy nix-gc.service (which runs at boot via `nix.gc.persistent`), and
  # without the gate it probed before the link was up, failed twice and spent
  # 12.1 s instead of 0.3 s. Same total, less predictable.

  boot.kernelParams = [
    # pti=off was tried here on 2026-10-22 (gens 60 and 62) and both boots came
    # back unusable while gen 61 booted fine, so it is out until someone watches
    # a boot with it and can say what actually failed. Baseline for a re-test on
    # the proven kernel: 3000 fork+exec = 22.7 s (7.6 ms each).
    # "fsck.mode=skip"
    # "nomodeset"
    # "console=tty1"
    # "quiet" "loglevel=3"
    # Home: .agents/deploy/hosts/netbook.md §"`pti=off` black-panels this machine".
  ];
  boot.kernel.sysctl = {
    "vm.swappiness" = 100;
    # zram is the swap device that actually gets used (1.8 GiB, 3.76:1 measured).
    # Decompressing 8 pages to satisfy a 1-page fault is wasted CPU here.
    "vm.page-cluster" = 0;
    "vm.vfs_cache_pressure" = 150;
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
  };
  # Verbose on purpose: this machine has no serial port, and at the old level 3
  # a failing boot was indistinguishable from a frozen screen — generation 50
  # died with nothing on the console to read.
  boot.consoleLogLevel = 7;
  nix.optimise.automatic = true;
  # Flake-only, matching the fleet: the NixOS default appends
  # `/nix/var/nix/profiles/per-user/root/channels` to NIX_PATH, which this host
  # no longer populates, so every `<nixpkgs>` lookup warned it did not exist.
  nix.channel.enable = false;
  nix.gc = {
    automatic = true;
    persistent = true;
    dates = "weekly";
    # Nix 2.31 wants `--delete-older-than 30d` (space); the hyphenated form this
    # machine shipped with is not a flag, so every run exited 1 and generations
    # piled up until the eMMC was 84 %% full. Measured: `nix-collect-garbage
    # --help` lists the space-separated form only.
    # 30 d (this host's old value) meant a day of deploy testing could keep five
    # generations alive for a month against a 6.7 GiB closure. A week still
    # covers "broke it, fix it tomorrow" without hoarding.
    options = "--delete-older-than 7d";
  };
  nix.settings = {
    # This host only receives closures (`nix copy` from frieren); it never builds
    # or imports by hand, so hashing every path written is a tax on each deploy
    # with no dedupe to show for it. The weekly optimise timer still runs.
    auto-optimise-store = false;
    # Flakes on, because this host is now a fleet host rather than a channel
    # island: deploys resolve `.#nixosConfigurations.netbook`.
    experimental-features = ["nix-command" "flakes"];
    # The LAN cache is 3.4 ms away and answers 200 from here (measured), but the
    # image shipped with cache.nixos.org only — so nothing it already had on the
    # NAS was ever used, and every rebuild went to the WAN.
    # cache.nixos.org is added by the module (and appears twice if listed here).
    substituters = [
      "http://192.168.3.25:5000"
      "https://shaoyanji.cachix.org"
      "https://cache.numtide.com"
    ];
    trusted-public-keys = [
      "frieren.lan-1:BUg+1UmfYlF0XCbC0+ZyWQOY1DpQJhj/wa2q76NTFOg="
      "shaoyanji.cachix.org-1:3XUZGFcaq5bXFKwtCR+POG81Hh6WfTqf50Bmz4VHpj0="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
    trusted-substituters = ["http://192.168.3.25:5000"];
  };
  services.journald.settings.Journal = {SystemMaxUse = "50M";};
  # LTS, not latest: the newest kernel (`linuxPackages_latest`) could not mount
  # the f2fs root on this eMMC — the failure that pinned the whole host to 25.11.
  boot.kernelPackages = pkgs.linuxPackages;
  # NixOS 26.11 defaults `boot.initrd.systemd.enable` to TRUE, so following the
  # fleet nixpkgs silently swapped the scripted busybox stage-1 this box has
  # booted for a year for systemd-initrd. Generation 50 (systemd-initrd +
  # 6.18.56) produced no journal entry at all: it never reached stage-2. The
  # scripted stage-1 is the variant generation 49 proves on this hardware.
  boot.initrd.systemd.enable = false;

  zramSwap = {
    priority = 100;
    enable = true;
    memoryPercent = 100;
    algorithm = "lz4";
  };
  powerManagement.enable = true;
  services.tlp.enable = true;
  # thermald regulates through Intel DPTF/RAPL thermal tables; this Celeron N3060
  # (Braswell) exposes none, so the daemon had nothing to act on. TLP is the power
  # path here and already owns the CPU knobs.
  services.thermald.enable = false;
  services.earlyoom.enable = true;
  networking.hostName = "netbook"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # Firmware TPM (Intel PTT, ACPI MSFT0101) — the netbook's sops identity. The
  # chip is only useful once `tss` owns /dev/tpmrm0, and the sealed identity is
  # generated ON this host as alice, so alice needs the group. Procedure and
  # traps: docs/sops-rekey.md § TPM-sealed identity. The sealed key lives at
  # ~alice/.config/sops/age/tpm-identity-netbook.txt with `keys.txt` symlinked
  # to it, so plain `sops -d` finds the TPM identity with no env var and no
  # keyFile to configure. Its recipient is `.sops.yaml`'s `&tpmnetbook` — the
  # one identity here that is not derived from an SSH key. No sops-nix plane
  # is wired yet, so it is used by hand.
  security.tpm2 = {
    enable = true;
    tctiEnvironment.enable = true;
  };

  users.users.alice = {
    isNormalUser = true;
    extraGroups = ["wheel" "tss"]; # wheel = sudo, tss = /dev/tpmrm0

    openssh.authorizedKeys.keys = [deployKey];
    packages = with pkgs; [
      tree
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  profiles.voiceDictate.enable = true;
  profiles.dwlDesktop = {
    enable = true;
    user = "alice";
    # A 1024x600 panel: the profile's default 11 is two rows of text short.
    font = "JetBrainsMono NFM:size=9";
    # The store copy of `fjordWallpaper` above, with no dependency on $HOME or
    # on the NAS being mounted.
    wallpaper = "${fjordWallpaper}";
    # Their keyboard's ribbon connector is broken, so this is the workaround
    # layer for the dead keys, spliced into the fleet keymap ahead of it (first
    # match wins). The file explains itself; `extraKeybinds` in the profile owns
    # the mechanism.
    extraKeybinds =
      builtins.replaceStrings
      ["/* @DEAD_KEYS@ */"]
      [deadKeyRows]
      (builtins.readFile ./dwl-keybinds.h);
    # The two `spawn-at-startup` lines from niri worth keeping: the battery
    # sentinel (the bar is gone, so its alerts come from here) and the taildrop
    # receiver. waybar's line is deliberately absent, and swayidle/swaybg are the
    # session's own job now.
    # fnott owns org.freedesktop.Notifications for the ~/mako-suite cards and
    # every `notify()` in alice's scripts. Two daemons would race for that name,
    # which is why the port of the cards and this line are one change.
    autostart = [
      "fnott"
      "makobatt -s"
      "taildrop --daemon"
    ];
  };

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    # The dead-key table as a fnott card; `netbook-keys --text` prints it instead.
    keysCard
    age-plugin-tpm # unseals the TPM-sealed sops identity
    tpm2-tools
    sops # the other half: `SOPS_AGE_KEY_FILE=~/… sops -d`

    git
    curl
    wget
    eget
    sqlite
    # Only what dwlDesktop does not own — it carries the compositor, terminal,
    # launcher, wallpaper, notifications, idle, lock and the nerd font. Keep
    # this list small: 326 MiB of dev tooling was measured out of it on a 1.8 GiB
    # Celeron, and pcmanfm is here at 4.7 MiB instead of nautilus.
    pavucontrol
    polkit_gnome
    bibata-cursors
    pcmanfm
    btop
    fastfetch
    # firefox is back as a package, not as the module (2026-11-04): the ~590 MiB
    # measured on 2026-10-27 was the NixOS module pulling ML runtimes, and
    # `programs.firefox` stays off for that reason. `xdg-desktop-portal` stays
    # (17 MiB): it owns the file-attach and screen-share dialogs.
    firefox
    tmux
    lowfi
    # mpv
    # nushell
    rsync
    mupdf
    # freetube
    # yt-dlp
    # yewtube
    fzf
    jq
    gum
    ripgrep
    fd
    bat
    eza
    zoxide
    duf
    tldr
    unzip
    zip
    file
    # youtubeSupport=false keeps mpv's wrapper from pinning the stale
    # nixpkgs yt-dlp into its PATH; the current yt-dlp comes from
    # /home/alice/.local/bin/yt-dlp (standalone binary, self-updates with
    # `yt-dlp --update`).
    (mpv.override {youtubeSupport = false;})
    aria2
    # ani-cli prefers curl-impersonate (hianime sits behind Cloudflare)
    curl-impersonate
    # VAAPI diagnostics (vainfo)
    libva-utils
    xwayland-satellite # xwayland support
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
  };

  # The Nerd Font comes from `profiles.dwlDesktop` — foot, wmenu and dwl all
  # name it — so only the colour emoji is this host's.
  fonts.packages = [pkgs.noto-fonts-color-emoji];

  # Bluetooth radio is present (hci0); enable the stack.
  hardware.bluetooth.enable = true;

  # VAAPI driver for the Gen8 iGPU (N3060): H.264 hardware decode for mpv.
  hardware.graphics.extraPackages = [pkgs.intel-vaapi-driver];

  # Run prebuilt, non-Nix dynamically linked binaries (tools dropped in
  # ~/.local/bin, pip/venv wheels with C extensions, downloaded release
  # tarballs) through nix-ld's loader. Extra libs can be added via
  # programs.nix-ld.libraries if something complains about a missing .so.
  programs.nix-ld.enable = true;

  # Keep ~/.local/bin on PATH for the session and login shells.
  environment.localBinInPath = true;

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      TrustedUserCAKeys = "${pkgs.writeText "trusted-user-ca" "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMhAN2tuJ4f8kCbCWehJL+fp5VYrTUQpn2ZWK9RC7XM1 SSH User CA @ aristotle 20260706\n"}";
    };
  };

  # Never bump: it gates state migrations, not the package set.
  system.stateVersion = "25.11";
}
