{
  lib,
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./nixoshmsymlinks.nix
    ./himalaya.nix
  ];
  programs.nixvim.enable = true;
  home.activation.removeExistingGitConfig = lib.hm.dag.entryAfter ["checkLinkTargets"] ''
    rm -f ~/.gitconfig
  '';
  programs.delta = {
    enableGitIntegration = true;
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
  programs.gh = {
    enable = true;
    extensions = with pkgs; [
      gh-s
      # gh-i
      gh-f
      gh-eco
      gh-cal
      gh-notify
      gh-markdown-preview
      gh-skyline
    ];
    settings = {
      git_protocol = "ssh";
      editor = "nvim";
      prompt = "enabled";
      preferred_editor_prompt = "disabled";
      pager = "bat";
      aliases = {
        co = "pr checkout";
        pv = "pr view";
      };
    };
  };
  programs.git = {
    enable = true;
    settings = {
      user.name = lib.mkForce "Shao-yan (Matt) Ji";
      user.email = lib.mkForce "github@mail.shaoyanji@is-a.dev";
      init.defaultBranch = lib.mkForce "master";
      pull.rebase = lib.mkForce true;
      push.autoSetupRemote = true;
      alias = {
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
    includes = [
      {
        path = "~/Documents/work/.gitconfig";
        condition = "gitdir:~/Documents/work";
      }
    ];
  };
  home.sessionVariables = {
  };
  home.packages = with pkgs; [
    lazygit
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
