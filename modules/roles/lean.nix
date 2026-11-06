# `role:lean` — the operator's toolbox and nothing else: no desktop, no AI stack,
# no nixvim, no sops, so it activates with no age key on a box that is not a fleet
# host. Deliberately not `role:minimal`, which imports the AI stack. Where it is
# used and why: .agents/skills/instabox/SKILL.md.
{
  pkgs,
  lib,
  ...
}: let
  user = import ../global/user.nix;
in {
  home = {
    # mkDefault: a host whose login account is not `devji` (clanker's is `user`)
    # overrides these two lines instead of redefining the toolbox.
    username = lib.mkDefault user.name;
    homeDirectory = lib.mkDefault user.home;
    stateVersion = "24.11";
    sessionPath = ["$HOME/.local/bin"];
    packages = with pkgs;
      [
        git
        gh
        go-task
        ripgrep
        fd
        jq
        yq-go
        bat
        tmux
        direnv
        nix-direnv
        shellcheck
        shfmt
        rsync # absent from instabox images, and the difference between a job and a hand-copy
        curl
        wget
        openssh
        unzip
        file
        go
        nodejs_22
        python3
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        htop
        procps
      ];
  };

  programs = {
    home-manager.enable = true;
    git = {
      enable = true;
      # `settings`, not the removed `userName`/`extraConfig` options: this HM
      # release turns the old ones into a failed assertion.
      settings = {
        user = {
          name = user.realName;
          email = user.githubEmail;
        };
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
      };
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    bat.enable = true;
  };
}
