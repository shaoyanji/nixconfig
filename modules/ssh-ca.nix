{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.ssh.ca;
  user = import ./global/user.nix;
  caPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMhAN2tuJ4f8kCbCWehJL+fp5VYrTUQpn2ZWK9RC7XM1 SSH User CA @ aristotle 20260706";

  # Timer-driven renewal: signs a fresh 90-day cert for the primary user
  # (devji-only principals — the old alice/root principals came from an
  # unknown one-off signing and are deliberately dropped; root logins use
  # authorized_keys). Weekly cadence keeps it fresh unattended; signing is
  # idempotent (ssh-keygen -s overwrites the cert in place, non-interactive).
  renewSshCert = pkgs.writeShellScriptBin "renew-ssh-cert" ''
    set -euo pipefail
    CA_KEY="$HOME/.ssh/user_ca_key"
    USER_KEY="$HOME/.ssh/id_ed25519"

    if [ ! -f "$CA_KEY" ]; then
      echo "ERROR: CA private key not found at $CA_KEY." >&2
      echo "Run 'sops decrypt' or rebuild with sops-nix first." >&2
      exit 1
    fi
    if [ ! -f "$USER_KEY.pub" ]; then
      echo "ERROR: User public key not found at $USER_KEY.pub" >&2
      exit 1
    fi

    ${pkgs.openssh}/bin/ssh-keygen -s "$CA_KEY" \\
      -I "$(whoami)@$(hostname)-$(date +%Y%m%d)" \\
      -n "${user.name}" \\
      -V "+90d" \\
      "$USER_KEY.pub"
    echo "Certificate renewed: $USER_KEY-cert.pub (valid 90 days)"
  '';
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
        renewSshCert
        (writeShellScriptBin "rotate-ssh-cert" ''
          # Manual alias for renew-ssh-cert (kept for muscle memory).
          exec renew-ssh-cert
        '')
      ];

      # Unattended renewal (weekly, catches up after downtime via
      # Persistent). Linger must be on for the timer to fire without a
      # login session — devji is lingered on frieren.
      systemd.user.services.renew-ssh-cert = {
        description = "Renew the ${user.name} SSH user certificate (90-day validity)";
        serviceConfig = {
          Type = "oneshot";
          ConditionUser = user.name;
          Environment = [
            "HOME=${user.home}"
            "PATH=${pkgs.coreutils}/bin"
          ];
          ExecStart = "${renewSshCert}/bin/renew-ssh-cert";
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };

      systemd.user.timers.renew-ssh-cert = {
        description = "Renew the SSH user certificate weekly";
        timerConfig = {
          OnCalendar = "Mon *-*-* 04:30:00";
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
        wantedBy = ["timers.target"];
      };
    })
  ];
}
