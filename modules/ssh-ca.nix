{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.ssh.ca;
  caPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDi7mArveXiOL26h0j4qgEZB3gPV+x7un0SwKQD+mn2J SSH User CA @ poseidon 20260705";
in {
  options.ssh.ca = {
    enable = mkEnableOption "SSH CA trust — accept certificates signed by the user CA";

    enableClient = mkEnableOption "SSH client certificate config — use cert automatically";

    revokedKeysFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to a revoked keys file for sshd";
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      services.openssh.settings = {
        TrustedUserCAKeys = "${pkgs.writeText "trusted-user-ca" caPublicKey}";
        RevokedKeys = mkIf (cfg.revokedKeysFile != null) cfg.revokedKeysFile;
      };
    })

    (mkIf cfg.enableClient {
      programs.ssh.extraConfig = ''
        CertificateFile ~/.ssh/id_ed25519-cert.pub
      '';

      environment.systemPackages = with pkgs; [
        (writeShellScriptBin "rotate-ssh-cert" ''
          set -e
          CA_KEY="$HOME/.ssh/user_ca_key"
          USER_KEY="$HOME/.ssh/id_ed25519"
          USER="devji"

          if [ ! -f "$CA_KEY" ]; then
            echo "ERROR: CA private key not found at $CA_KEY." >&2
            echo "Run 'sops decrypt' or rebuild with sops-nix first." >&2
            exit 1
          fi

          if [ ! -f "$USER_KEY.pub" ]; then
            echo "ERROR: User public key not found at $USER_KEY.pub" >&2
            exit 1
          fi

          ssh-keygen -s "$CA_KEY" \
            -I "$(whoami)@$(hostname)-$(date +%Y%m%d)" \
            -n "$USER" \
            -V "+1w" \
            "$USER_KEY.pub"

          echo "Certificate signed: $USER_KEY-cert.pub (valid 1 week)"
        '')
      ];
    })
  ];
}
