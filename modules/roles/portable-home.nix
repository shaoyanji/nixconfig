{...}: {
  # Portable contract used directly by penguin; equivalent baseline also holds for alarm/kali via minimal → user/base.
  imports = [
    ../shell/base.nix
  ];

  programs.nixvim.enable = true;
}
