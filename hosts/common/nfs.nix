{  
  fileSystems."/mnt/w" = {
    device = "burgernas.fritz.box:/volume1/peachcable";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" "x-systemd.after=network-online.target" "x-systemd.mount-timeout=30" ];
  };
}
