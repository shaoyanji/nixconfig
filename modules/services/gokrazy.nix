# Gokrazy appliances declared in Nix: secret injection, schema and config generation.
{
  config,
  lib,
  ...
}: let
  cfg = config.services.gokrazy;

  # gok reads PackageConfig as a map keyed by go module path. Empty fields are
  # dropped: `"CommandLineFlags": []` and an absent key are not the same thing
  # to gok, and an empty ExtraFileContents would overwrite a module's own file.
  # `lib.recursiveUpdate`, not `//`: a host that sets its own breakglass flags
  # must keep them next to the ones this module adds.
  renderPackageConfig = inst:
    lib.mapAttrs (_: c:
      lib.filterAttrs (_: v: v != null) {
        # `or` defaults: a submodule entry has all three keys, a merged-in plain
        # attrset may not, and a missing key here is an eval error, not a skip.
        CommandLineFlags =
          if (c.commandLineFlags or []) == []
          then null
          else c.commandLineFlags;
        ExtraFilePaths =
          if (c.extraFilePaths or {}) == {}
          then null
          else c.extraFilePaths;
        ExtraFileContents =
          if (c.extraFileContents or {}) == {}
          then null
          else c.extraFileContents;
      })
    (mergedPackageConfig inst);

  mergedPackageConfig = inst:
    lib.recursiveUpdate inst.packageConfig (
      lib.optionalAttrs inst.breakglass.enable {
        "github.com/gokrazy/breakglass" = {
          extraFilePaths."/etc/breakglass.authorized_keys" = inst.breakglass.authorizedKeysFile;
          commandLineFlags = ["-authorized_keys=/etc/breakglass.authorized_keys"];
        };
      }
      // lib.optionalAttrs inst.tailscale.enable {
        "tailscale.com/cmd/tailscale".commandLineFlags = ["up" "--hostname=${inst.tailscale.hostname}"];
      }
      // lib.optionalAttrs (inst.wifi.ssidSecret != null) {
        # The file ships as a pair of empty strings on purpose: the real values are
        # injected from sops after rendering, so the store never holds the PSK.
        "github.com/gokrazy/wifi".extraFileContents."/etc/wifi.json" =
          builtins.toJSON {
            ssid = "";
            psk = "";
          }
          + "\n";
      }
    );

  # Each slot says: this JSON path gets its value from this sops key. `append`
  # marks the one path that is a LIST (tailscale flags), where the runtime
  # appends a flag rather than replacing the list.
  secretsOf = inst:
    lib.filterAttrs (_: v: v != null) {
      httpPassword = {
        sopsKey = inst.httpPasswordSecret;
        jsonPath = ["Update" "HTTPPassword"];
      };
      tailscaleAuthKey =
        if inst.tailscale.authKeySecret == null
        then null
        else {
          sopsKey = inst.tailscale.authKeySecret;
          jsonPath = ["PackageConfig" "tailscale.com/cmd/tailscale" "CommandLineFlags"];
          append = "--auth-key=";
        };
      wifi =
        if inst.wifi.ssidSecret == null
        then null
        else {
          jsonPath = ["PackageConfig" "github.com/gokrazy/wifi" "ExtraFileContents" "/etc/wifi.json"];
          json = true;
          sopsKeys = {
            ssid = inst.wifi.ssidSecret;
            psk = inst.wifi.pskSecret;
          };
        };
    };

  render = inst: {
    configJSON = builtins.toJSON (
      {
        Hostname = inst.hostname;
        Update.HTTPPassword = "";
        Packages = inst.packages;
        SerialConsole = inst.serialConsole;
      }
      // lib.optionalAttrs (inst.environment != []) {Environment = inst.environment;}
      // lib.optionalAttrs (mergedPackageConfig inst != {}) {PackageConfig = renderPackageConfig inst;}
    );
    secretSlots = secretsOf inst;
  };
in {
  options.services.gokrazy = {
    instances = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
        options = {
          hostname = lib.mkOption {
            type = lib.types.str;
            description = "DHCP hostname and the name `gok update` resolves.";
          };

          packages = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Go module paths the appliance serves, e.g. github.com/gokrazy/breakglass.";
          };

          environment = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Go build environment for the target, e.g. GOOS=linux, GOARCH=arm64.";
          };

          serialConsole = lib.mkOption {
            type = lib.types.enum ["disabled" "console" "console=ttyS0,115200"];
            default = "disabled";
            description = "gokrazy SerialConsole setting.";
          };

          packageConfig = lib.mkOption {
            default = {};
            description = ''
              Per-module flags and files, keyed by go module path. ExtraFileContents
              is for NON-secret files only — a credential belongs in a sops slot.
            '';
            type = lib.types.attrsOf (lib.types.submodule {
              options.commandLineFlags = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
              };
              options.extraFilePaths = lib.mkOption {
                type = lib.types.attrsOf lib.types.str;
                default = {};
              };
              options.extraFileContents = lib.mkOption {
                type = lib.types.attrsOf lib.types.str;
                default = {};
              };
            });
          };

          httpPasswordSecret = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = "gokrazy.${name}.http_password";
            description = "sops key holding the gok update HTTP password.";
          };

          breakglass = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
            authorizedKeysFile = lib.mkOption {
              type = lib.types.str;
              default = "breakglass.authorized_keys";
              description = "File gok.sh writes from the fleet key list (modules/config/authorized-keys.nix).";
            };
          };

          tailscale = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
            hostname = lib.mkOption {
              type = lib.types.str;
              default = name;
            };
            authKeySecret = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "sops key for an unattended auth key; null = the appliance prints a login URL instead.";
            };
          };

          wifi = {
            ssidSecret = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "sops key for the SSID — the network name is not published in this repo either.";
            };
            pskSecret = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
          };
        };
      }));
      default = {};
      description = "Declared gokrazy appliances, keyed by instance name.";
    };

    rendered = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = lib.mapAttrs (_: render) cfg.instances;
      description = ''
        The projection `scripts/task/gok.sh` consumes: `configJSON` (the full
        config.json with empty credential slots) and `secretSlots` (which sops
        key fills which JSON path, and whether it appends or replaces).
      '';
    };
  };

  config = {};
}
