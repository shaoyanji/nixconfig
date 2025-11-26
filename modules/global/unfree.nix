{lib, ...}: {
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "obsidian"
      "ngrok"
      "dropbox"
      "firefox-bin"
      "firefox-bin-unwrapped"
      "intel-ocl-5.0-63503"
      "intel-ocl"
      "tabnine"
    ];
}
