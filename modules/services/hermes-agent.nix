{
  config,
  lib,
  pkgs,
  inputs ? {},
  ...
}: let
  cfg = config.aiServices.hermesAgent;
  defaultSkillsSource =
    if inputs ? hermes-src
    then inputs.hermes-src
    else null;
in {
  options.aiServices.hermesAgent = {
    enable = lib.mkEnableOption "Hermes agent service bundle";
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Hermes agent package. Required when `aiServices.hermesAgent.enable = true`.";
    };
    workspaceRoot = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/hermes";
      description = "Hermes state/workspace root for host-level bind mount assumptions.";
    };
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/hermes";
      description = "Optional EnvironmentFile for the hermes-agent service.";
    };
    skillsSource = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = defaultSkillsSource;
      description = "Optional source path containing `skills/` and `optional-skills/` to sync at startup.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "aiServices.hermesAgent.package must be set when aiServices.hermesAgent.enable = true";
      }
    ];

    services.hermes-agent = {
      enable = true;
      package = cfg.package;
      environmentFiles = lib.optionals (cfg.environmentFile != null) [cfg.environmentFile];

      skills.bundled.enable = lib.mkForce false;
      skills.bundled.include = lib.mkForce [];
      skills.optional = lib.mkForce [];
      skills.custom = lib.mkForce {};

      config = {
        model = {
          provider = "openrouter";
          default = "nvidia/nemotron-3-super-120b-a12b:free";
        };
        terminal = {
          backend = "local";
          timeout = 180;
        };
        toolsets = ["all"];
      };
    };

    systemd.services.hermes-agent = {
      path = config.environment.systemPackages ++ (with pkgs; [rsync git nodejs_22 ripgrep ffmpeg]);
      preStart =
        ''
          install -d -m 0755 ${cfg.workspaceRoot}/.hermes/skills
          install -d -m 0755 ${cfg.workspaceRoot}/.hermes/optional-skills
        ''
        + lib.optionalString (cfg.skillsSource != null) ''
          if [ -d "${cfg.skillsSource}/skills" ]; then
            rsync -a --delete "${cfg.skillsSource}/skills/" ${cfg.workspaceRoot}/.hermes/skills/
          fi

          if [ -d "${cfg.skillsSource}/optional-skills" ]; then
            rsync -a --delete "${cfg.skillsSource}/optional-skills/" ${cfg.workspaceRoot}/.hermes/optional-skills/
          fi
        ''
        + ''
          chown -R hermes:hermes ${cfg.workspaceRoot}/.hermes/skills ${cfg.workspaceRoot}/.hermes/optional-skills
        '';
    };

    sops.secrets.hermes = {
      owner = "hermes";
      group = "hermes";
      mode = "0400";
    };
  };
}
