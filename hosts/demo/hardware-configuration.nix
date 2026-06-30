# Demo — travel netbook.
# Do not import hardware scan; use generic laptop profile instead.
{...}: {
  imports = [
    ../../modules/profiles/laptop.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
