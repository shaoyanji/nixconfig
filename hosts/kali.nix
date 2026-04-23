{ pkgs, lib, ... }:

# Kali Home Manager profile
# Targets: Raspberry Pi (aarch64) + OnePlus 6 NetHunter Pro (chroot aarch64)
# Contract: mobile-first security starter pack. Everything here must build on
# aarch64-linux and be useful without a GUI. Heavy tools (Ghidra, Burp,
# full Metasploit) are intentionally omitted — they belong on a laptop or
# dedicated x86 rig. Phone storage is tight; every package earns its place.

{
  home.username = "kali";
  home.homeDirectory = "/home/kali";

  imports = [
    ../modules/shell/nushell.nix
    ../modules/shell/starship.nix
    ../modules/roles/minimal.nix
  ];

  home.packages = with pkgs; [
    # === RECONNAISSANCE & SCANNING ===
    # Core network discovery. nmap + NSE covers most initial enumeration.
    # rustscan is async and fast for quick port sweeps before deeper nmap.
    nmap
    rustscan
    arp-scan

    # === WEB APPLICATION TESTING ===
    # gobuster — dir/DNS/vhost busting (already battle-tested in this repo).
    # ffuf replaces wfuzz for modern web fuzzing (JSON output, easy POST fuzzing).
    # sqlmap is still the standard for automated SQLi.
    gobuster
    ffuf
    sqlmap
    nikto

    # === WIRELESS AUDITING ===
    # aircrack-ng suite: monitor mode required. On NetHunter Pro use wlan1
    # (internal WiFi via the NetHunter kernel patch). On Pi, use a USB adapter
    # with known-good monitor mode (Alfa AWUS036ACM / mt76x2u is solid).
    # wifite2 automates the whole WPA/WPS workflow but pulls a lot of deps.
    # bettercap is ARP spoofing, passive sniffing, and credential harvesting.
    aircrack-ng
    iw
    bettercap
    # wifite2        # Uncomment if you want fully automated WiFi auditing.
    # reaverwps-t6x  # WPS PIN attack. Verify package name in nixpkgs.
    # hcxtools       # Convert captures for hashcat. Uncomment if you have GPU.

    # === PASSWORD ATTACKS ===
    # john — CPU cracker. Works everywhere. Good for hashes you collect on-device.
    # hashcat — mostly useless on Pi/phone (no OpenCL on ARM). Included anyway
    #   because hashcat-utils (cap2hccapx, etc.) are useful for preparing captures.
    # hydra — parallel network login brute force.
    # crunch — generate wordlists by charset/length.
    john
    hashcat
    hydra
    crunch

    # === FORENSICS & STEGANOGRAPHY ===
    # steghide — hide/extract data in images. Pair with stegseek for speed.
    # binwalk — firmware and binary carving. Essential for embedded/IoT work.
    # exiftool — metadata inspection for OSINT and file analysis.
    # testdisk/foremost — file recovery and carving.
    steghide
    binwalk
    exiftool
    testdisk
    foremost
    # stegseek       # Fast steghide cracker. Verify nixpkgs name.
    # zsteg          # PNG/BMP stego detection. Ruby-based, may be heavy.

    # === REVERSE ENGINEERING ===
    # radare2 — the standard ARM/x86 RE framework. Lightweight enough for Pi.
    # rizin — cleaner fork of r2. Pick one or keep both; they coexist fine.
    # gdb — classic debugger. Pair with pwndbg if you install it manually
    #   (pwndbg is not in nixpkgs; clone from github.com/pwndbg/pwndbg).
    # strace/ltrace — observe syscalls and library calls without disassembly.
    radare2
    rizin
    gdb
    strace
    ltrace
    binutils          # objdump, strings, readelf

    # === EXPLOITATION & CTF ===
    # pwntools — Python framework for exploit dev and CTF. Huge dependency tree
    #   but worth it if you write exploits on-device.
    # ropgadget — find ROP chains in binaries.
    # checksec — quick binary hardening check (NX, PIE, Canary, RELRO).
    # nasm — assembler for writing shellcode.
    pwntools
    ropgadget
    checksec
    nasm

    # === MOBILE / ANDROID ===
    # adb/fastboot — talk to Android devices, including the host phone itself.
    # apktool — decode/rebuild APKs. NOTE: depends on aapt which is x86-only
    #   in nixpkgs. Use on x86, or run via box64/proot on ARM.
    # dex2jar — convert Dalvik bytecode to JAR. Usually works on ARM.
    android-tools
    # apktool
    dex2jar
    # jadx           # Android decompiler. Java-based, heavy. Skip on phone.
    # frida-tools    # Dynamic instrumentation. Powerful but large Python tree.

    # === NETWORKING & TUNNELING ===
    # proxychains-ng — force any TCP through SOCKS/HTTP proxy. Essential for pivoting.
    # socat — the actual socket swiss army knife. netcat with SSL, UDP, PTY support.
    # ncat — nmap's netcat with TLS and connection brokering.
    # chisel — TCP tunnel over HTTP. Single binary, great for C2 / pivoting.
    # sshuttle — poor man's VPN over SSH. No root needed on the server side.
    proxychains-ng
    socat
    # ncat — nmap's netcat with TLS and connection brokering.
    #   Bundled with nmap (already listed above); no separate package needed.
    chisel
    sshuttle

    # === OSINT ===
    # theHarvester — email harvesting via search engines and SHODAN.
    # recon-ng is a full OSINT framework but pulls a heavy Python dependency tree;
    # leave it commented unless you need the full pipeline.
    theharvester
    # recon-ng

    # === SCRIPTING & CUSTOM TOOLS ===
    # Go is already present — good for building fast static binaries on-device.
    # Python 3 with standard library for quick scripts and pwntools.
    # Perl and Ruby are dependency hell for many legacy security tools; omit unless
    # a specific tool demands them.
    go
    python3

    # === CULTURE ===
    # Because a terminal without rainbows is just a log file.
    lolcat
    figlet
    jp2a
  ];

  # Session environment tuned for security work.
  home.sessionVariables = {
    TERM = "xterm-256color";

    # Default Invidious instance for yt-dlp. Rotate if this one dies.
    invidious_instance = "https://inv.perditum.com";

    # Proxychains defaults — useful for quick pivoting without editing config.
    PROXYCHAINS_QUIET_MODE = "1";

    # Prefer rustscan's ultraspeed but keep nmap accuracy for detailed work.
    RUSTSCAN_BATCH_SIZE = "1500";
  };

  # Quick shell conveniences for common security workflows.
  home.shellAliases = {
    # Networking shortcuts
    ports = "ss -tuln";
    myip = "curl -s https://ipinfo.io/ip";

    # Web quick-checks
    headers = "curl -sI -o /dev/null -w '%{http_code} %{content_type} %{size_download}'";

    # Reverse engineering shortcuts
    r2 = "rizin";            # Prefer rizin for daily RE; keep r2 for scripting
    strings = "strings -a";  # Extract all strings, not just initialized data

    # Steganography quick checks
    exif = "exiftool -a -u -g1";

    # Process and system observation
    listening = "sudo ss -tulnp";
  };

  # Shell integrations already inherited from nushell + starship + minimal.
  # direnv, zoxide, fzf are host-local choices not guaranteed by roles/minimal.
  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableNushellIntegration = true;
    };
    zoxide = {
      enable = true;
      enableNushellIntegration = true;
    };
    fzf = {
      enable = true;
    };
  };

  programs.home-manager.enable = true;
}
