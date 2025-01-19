{pkgs,config,inputs,...}:
{
  fileSystems."/mnt/y" = {
  	device = "//fritz.box/fritz.nas/External-USB3-0-01/";
  	fsType = "cifs";
  	options = let
  		automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
  		reg_opts = "rw,noserverino,credentials=${config.sops.secrets."server/keyrepo/credentials".path},uid=1000,gid=1";
  		in
  		["${automount_opts},${reg_opts}"];
  };
  fileSystems."/mnt/z" = {
  	device = "//burgernas/usbshare2";
  	fsType = "cifs";
  	options = let
  		automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
  		reg_opts = "rw,noserverino,credentials=${config.sops.secrets."server/localwd/credentials".path},uid=1000,gid=1";
  		in
  		["${automount_opts},${reg_opts}"];
  };
  fileSystems."/mnt/x" = {
  	device = "//burgernas/Shared Library";
  	fsType = "cifs";
  	options = let
  		automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
  		reg_opts = "rw,noserverino,credentials=${config.sops.secrets."server/localwd/credentials".path},uid=1000,gid=1";
  		in
  		["${automount_opts},${reg_opts}"];
  };
  fileSystems."/mnt/v" = {
  	device = "//burgernas/usbshare1";
  	fsType = "cifs";
  	options = let
  		automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
  		reg_opts = "rw,noserverino,credentials=${config.sops.secrets."server/localwd/credentials".path},uid=1000,gid=1";
  		in
  		["${automount_opts},${reg_opts}"];
  };

}
