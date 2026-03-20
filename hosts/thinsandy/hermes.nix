{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  services.hermes-agent = {
    enable = true;
    package = pkgs.hermes-agent;
    environmentFiles = [config.sops.secrets.hermes.path];

    skills.bundled.enable = lib.mkForce false;
    skills.bundled.include = lib.mkForce [];
    skills.optional = lib.mkForce [];
    skills.custom = lib.mkForce {};

    config = {
      model = {
        provider = "openrouter";
        default = "openrouter/free";
      };
      terminal = {
        backend = "local";
        timeout = 180;
      };
      toolsets = ["all"];
    };
  };

  systemd.services.hermes-agent = {
    path = with pkgs; [rsync git nodejs_22 ripgrep ffmpeg];
    preStart = ''
      install -d -m 0755 /var/lib/hermes/.hermes/skills
      install -d -m 0755 /var/lib/hermes/.hermes/optional-skills

      if [ -d "${inputs.hermes-src}/skills" ]; then
        rsync -a --delete "${inputs.hermes-src}/skills/" /var/lib/hermes/.hermes/skills/
      fi

      if [ -d "${inputs.hermes-src}/optional-skills" ]; then
        rsync -a --delete "${inputs.hermes-src}/optional-skills/" /var/lib/hermes/.hermes/optional-skills/
      fi

      chown -R hermes:hermes /var/lib/hermes/.hermes/skills /var/lib/hermes/.hermes/optional-skills
    '';
  };

  sops.secrets.hermes = {
    owner = "hermes";
    group = "hermes";
    mode = "0400";
  };
}
