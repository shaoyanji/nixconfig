{  
  fileSystems."/mnt/w" = {
    device = "192.168.178.4:/volume1/peachcable";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" "x-systemd.after=network-online.target" "x-systemd.mount-timeout=30" ];
  };
}
