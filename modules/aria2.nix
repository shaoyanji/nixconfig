{
  pkgs,
  lib,
  config,
  ...
}:
let
  aria2Conf = pkgs.writeText "aria2.conf" ''
    enable-rpc=true
    rpc-listen-port=6800
    rpc-listen-all=false
    rpc-allow-origin-all=true
  '';
in
{
  # User-level fallback daemon for hosts without the system-wide
  # services.aria2 (e.g. laptops/desktops when the NAS is unreachable).
  # Disable on hosts that run the system aria2 daemon (frieren) so exactly
  # one RPC owns :6800 — otherwise the unauthenticated fallback binds
  # [::1]:6800 and shadows the secret-protected system daemon.
  options.programs.aria2-user-fallback.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether to run the user-level aria2 RPC fallback daemon on
      localhost:6800 (unauthenticated, CLI-scripting friendly).
    '';
  };

  config = {
    home.packages = with pkgs; [ aria2 ];

    xdg.configFile."aria2/aria2.conf".source = aria2Conf;

    # Local fallback daemon — no secret, listens on localhost:6800 only.
    # Useful when frieren (the NAS) is unreachable and for CLI scripting.
    systemd.user.services.aria2 = lib.mkIf config.programs.aria2-user-fallback.enable {
      Unit = {
        Description = "aria2 RPC download daemon (local fallback)";
        After = [ "network.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.aria2}/bin/aria2c --conf-path=${aria2Conf} --enable-rpc";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
