{inputs, ...}: {
  imports = [
    ../modules/global/minimal.nix
    ../modules/shell
    ../modules/nixvim
  ];
  home = {
    username = "devji";
    homeDirectory = "/home/devji";

    # stateVersion = "24.11";
    file = {
    };

    sessionVariables = {
    };
    sessionPath = [];
  };
  xdg.configFile."systemd/user/cros-garcon.service.d/override.conf".text =
    /*
    ini
    */
    ''
      [Service]
      Environment="PATH=%h/.nix-profile/bin:%h/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/local/games:/usr/sbin:/usr/bin:/usr/games:/sbin:/bin"
      Environment="XDG_DATA_DIRS=%h/.nix-profile/share:%h/.local/share:%h/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share"
    '';

  programs.home-manager.enable = true;
}
