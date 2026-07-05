{pkgs, ...}: let
  aria2Conf = pkgs.writeText "aria2.conf" ''
    enable-rpc=true
    rpc-listen-port=6800
    rpc-listen-all=false
    rpc-allow-origin-all=true
  '';
in {
  home.packages = with pkgs; [aria2];

  xdg.configFile."aria2/aria2.conf".source = aria2Conf;

  # Local fallback daemon — no secret, listens on 127.0.0.1:6800 only.
  # Useful when thinsandy is unreachable and for CLI scripting.
  systemd.user.services.aria2 = {
    Unit = {
      Description = "aria2 RPC download daemon (local fallback)";
      After = ["network.target"];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.aria2}/bin/aria2c --conf-path=${aria2Conf} --enable-rpc";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = ["default.target"];
    };
  };
}