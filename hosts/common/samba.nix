{
  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /export 192.168.178.0/24(rw,fsid=0,no_subtree_check)
    /export/data 192.168.178.0/24(rw,async,no_wdelay,hide,crossmnt,no_subtree_check,insecure_locks,anonuid=1000,anongid=100,sec=sys,insecure,root_squash,all_squash)
    /export/data 100.66.146.18(rw,async,no_wdelay,hide,crossmnt,no_subtree_check,insecure_locks,anonuid=1000,anongid=100,sec=sys,insecure,root_squash,all_squash)
  '';
  services.samba = {
    enable = true;
    #  securityType = "user";
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "smbnix";
        "netbios name" = "smbnix";
        "security" = "user";
        #"use sendfile" = "yes";
        #"max protocol" = "smb2";
        # note: localhost is the ipv6 localhost ::1
        #"hosts allow" = "192.168.178.0 ";
        #"hosts deny" = "0.0.0.0/0";
        #"guest account" = "nobody";
        #"map to guest" = "bad user";
      };
      "data" = {
        "path" = "/export/data";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
        #"force user" = "devji";
        #"force group" = "";
      };
      "private" = {
        "path" = "/export/private";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
      };

      "public" = {
        "path" = "/export/public";
        "browseable" = "yes";
        "read only" = "yes";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  networking.firewall.allowedTCPPorts = [445 139 2049];
  networking.firewall.allowedUDPPorts = [137 138];
  networking.firewall.enable = true;
  networking.firewall.allowPing = true;
}
