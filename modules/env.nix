{
  lib,
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
  ];
  home.activation.removeExistingGitConfig = lib.hm.dag.entryAfter ["checkLinkTargets"] ''
    rm -f ~/.gitconfig
  '';
  programs.git = {
    enable = true;
    userName = lib.mkForce "Shao-yan (Matt) Ji";
    userEmail = lib.mkForce "100967396+shaoyanji@users.noreply.github.com";
    includes = [
      {
        path = "~/Documents/work/.gitconfig";
        condition = "gitdir:~/Documents/work";
      }
    ];
    extraConfig = {
      init.defaultBranch = lib.mkForce "master";
      pull.rebase = lib.mkForce true;
      push.autoSetupRemote = true;
    };
    delta = {
      enable = true;
      options = {
        side-by-side = true;
        use-fancy-line-numbers = true;
        highlight-renames = true;
        highlight-old-new-lines = true;
        highlight-new-old-lines = true;
        line-numbers = true;
      };
    };
    aliases = {
      co = "checkout";
      ci = "commit";
      st = "status";
      br = "branch";
      hist = "log --pretty=format:\"%h %ad | %s%d [%an]\" --graph --date=short";
      amend = "commit --amend";
      undo = "reset --soft HEAD~1";
      unstage = "reset HEAD";
      last = "log -1 HEAD";
      last-n = "log -n 1";
      stage = "add";
      stage-all = "add .";
      unstage-all = "reset";
      stash = "stash save";
      pop = "stash pop";
      #   undo-last="reset HEAD~1";
      sbupdate = "submodule update --init --recursive";
      sbforfetch = "submodule foreach git fetch origin";
      sbpull = "pull --recurse-submodules";
    };
  };
  home.sessionVariables = {
  };
  home.packages = with pkgs; [
    lazygit
    gh
    #   sops #managed by sops module
    #   yq
    #   yq-go#managed by sops module
    #   pass
    #   gnupg
    #   age
  ];

  home.file = {
  };
}
