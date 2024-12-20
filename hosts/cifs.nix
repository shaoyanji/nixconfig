{pkgs,configs,inputs,...}:
{
	#fileSystems."/mnt/w" = {
	#	device = "192.168.178.4:/volume1/peachcable";
	#	fsType = "nfs";
	#	options = [ "x-systemd.automount" "noauto" "x-systemd.after=network-online.target" "x-systemd.mount-timeout=30" ];
	#};

	fileSystems."/mnt/y" = {
		device = "//192.168.178.1/fritz.nas/External-USB3-0-01/";
		fsType = "cifs";
		options = let
			automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
			reg_opts = "rw,noserverino,username=jisifu,uid=$(id -u),gid=$(id -g)";
			in
			["${automount_opts},${reg_opts}"];
	};
	fileSystems."/mnt/z" = {
		device = "//burgernas/usbshare2";
		fsType = "cifs";
		options = let
			automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
			reg_opts = "rw,noserverino,credentials=/mnt/y/documents/secrets/credentials.txt,uid=$(id -u),gid=$(id -g)";
			in
			["${automount_opts},${reg_opts}"];
	};
	fileSystems."/mnt/x" = {
		device = "//burgernas/Shared Library";
		fsType = "cifs";
		options = let
			automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
			reg_opts = "rw,noserverino,credentials=/mnt/y/documents/secrets/credentials.txt,uid=$(id -u),gid=$(id -g)";
			in
			["${automount_opts},${reg_opts}"];
	};
}
