{...}: {
  # Portable baseline guaranteed across penguin/alarm/kali.
  imports = [
    ../shell/base.nix
  ];

  programs.nixvim.enable = true;
}
