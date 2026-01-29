{lib, ...}: {
  boot.initrd.postDeviceCommands =
    lib.mkAfter
    /*
    bash
    */
    ''
      mkdir /btrfs_tmp
      mount /dev/root_vg/root /btrfs_tmp
      if [[ -e /btrfs_tmp/root ]]; then
          mkdir -p /btrfs_tmp/old_roots
          timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
          mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
      fi

      delete_subvolume_recursively() {
          IFS=$'\n'
          for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
              delete_subvolume_recursively "/btrfs_tmp/$i"
          done
          btrfs subvolume delete "$1"
      }

      for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
          delete_subvolume_recursively "$i"
      done

      btrfs subvolume create /btrfs_tmp/root
      umount /btrfs_tmp
    '';

  fileSystems."/etc/ssh".neededForBoot = true;
  fileSystems."/etc/ssh".options = ["bind"];
  fileSystems."/etc/ssh".device = "/persist/system/etc/ssh";
  fileSystems."/persist".neededForBoot = true;
  environment.persistence."/persist/system" = {
    hideMounts = true;
    directories = [
      "/etc/nixos"
      "/etc/ssh" # for sops impermanence
      "/var/log"
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/tailscale"
      "/etc/NetworkManager/system-connections"
      "/etc/rancher/k3s"
      "/var/lib/rancher"

      {
        directory = "/var/lib/private/ollama";
        user = "ollama";
        mode = "u=rwx,g=,o=";
      }
      {
        directory = "/var/lib/colord";
        user = "colord";
        group = "colord";
        mode = "u=rwx,g=rx,o=";
      }
    ];
    files = [
      "/etc/machine-id"
      {
        file = "/var/keys/secret_file";
        parentDirectory = {mode = "u=rwx,g=,o=";};
      }
    ];
  };
  # impermanence display on seperate module
  services = {
    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
      };
    };

    btrfs.autoScrub = {
      enable = true;
      interval = "monthly";
      fileSystems = ["/"];
    };
  };
  programs.fuse.userAllowOther = true;
}
