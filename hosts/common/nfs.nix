{  
  fileSystems."/mnt/w" = {
    device = "192.168.178.4:/volume1/peachcable";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" "x-systemd.after=network-online.target" "x-systemd.mount-timeout=30" ];
  };
  #services.rpcbind.enable = true;
  #systemd.mount = [{
  #  type = "nfs";
  #  mountConfig = {
  #    Options = "noatime";
  #  };
  #  what = "192.168.178.4:/volume1/peachcable";
  #  where = "/mnt/w";
  #}]; 
  #systemd.automount = [{
  #  wantedBy = [ "multi-user.target" ];
  #  automountConfig = {
  #    TimeoutIdleSec = "30";
  #  };
  #  where = "/mnt/w";
  #}];
}
