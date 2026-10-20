# Derive the Home Manager sops identity from the host's SSH key.
#
# Two sops planes exist on a NixOS host and they do not share an identity:
#
#   * NixOS (root) — `modules/profiles/base-node.nix` sets
#     `sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"]`, so the host
#     key IS the identity. Nothing to bootstrap.
#   * Home Manager — `modules/sops.nix` needs an identity FILE the user can
#     read (`~/.config/sops/age/keys.txt`). `sshKeyPaths` is commented out
#     there on purpose: HM activation runs as the user, and the host key is
#     0600 root:root.
#
# On a host with no `~/.ssh/id_ed25519` this leaves nothing to bootstrap from.
# The fleet logs in with SSH CA certificates, so a fresh cloud VM has no user
# keypair at all, and sops-nix's `generateKey` would mint a random identity that
# is not a recipient in `.sops.yaml` — decryption then fails with
# "0 successful groups" and Home Manager activation aborts.
#
# `ssh-to-age` over a keypair is deterministic, so the identity derived here is
# **exactly** the recipient `.sops.yaml` already lists for the host: the host's
# anchor doubles as its user-plane recipient. No new recipient, no rekey, and
# nothing to back up — the host key regenerates it.
#
# Enable ONLY on hosts that do not use the TPM identity path (`modules/sops.nix`
# `tpmHosts` = frieren, fern): those read a TPM-sealed file, and a file written
# here would simply be ignored.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.profiles.sopsUserIdentity;

  hostKey = "/etc/ssh/ssh_host_ed25519_key";

  # Resolved from the system user, not hardcoded: if homeDirectory is ever
  # overridden, the identity must land where Home Manager reads it.
  homeDir = config.users.users.${cfg.user}.home;
  ageDir = "${homeDir}/.config/sops/age";
  target = "${ageDir}/keys.txt";

  group = config.users.users.${cfg.user}.group;
in {
  options.profiles.sopsUserIdentity = {
    enable = lib.mkEnableOption "derive the user's sops age identity from ${hostKey}";

    user = lib.mkOption {
      type = lib.types.str;
      default = (import ../global/user.nix).name;
      description = "Owner of the derived identity — the Home Manager user.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.users.users ? ${cfg.user};
        message = "profiles.sopsUserIdentity.user '${cfg.user}' is not a system user.";
      }
    ];

    # Activation order: `users` creates the account and its home; Home Manager
    # activation is a multi-user.target unit, so it always runs after this.
    system.activationScripts.sops-user-identity = {
      deps = ["users"];
      text = ''
        key=${lib.escapeShellArg hostKey}
        target=${lib.escapeShellArg target}

        if ! ${pkgs.coreutils}/bin/test -r "$key"; then
          echo "sops-user-identity: $key is not readable — skipped" >&2
        else
          want=$(${pkgs.ssh-to-age}/bin/ssh-to-age -private-key -i "$key")
          have=$(${pkgs.coreutils}/bin/cat "$target" 2>/dev/null || true)

          # Compare before writing: a switch that changes nothing must not
          # touch the file (it would invalidate nothing, but churn is noise).
          if [ "$want" = "$have" ]; then
            echo "sops-user-identity: $target already current"
          else
            ${pkgs.coreutils}/bin/install -d -m 0700 -o ${cfg.user} -g ${group} ${lib.escapeShellArg ageDir}
            tmp=$(${pkgs.coreutils}/bin/mktemp)
            printf '%s\n' "$want" > "$tmp"
            ${pkgs.coreutils}/bin/install -m 0600 -o ${cfg.user} -g ${group} "$tmp" "$target"
            ${pkgs.coreutils}/bin/rm -f "$tmp"
            echo "sops-user-identity: wrote $target (identity derived from the host key)"
          fi
        fi
      '';
    };
  };
}
