# starship: one prompt config for every shell the fleet runs.
{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.starship = {
    enable = true;
    # Configuration written to ~/.config/starship.toml
    settings = {
      palette = "catppuccin_mocha";
      palettes.catppuccin_mocha = {
        rosewater = "#f5e0dc";
        flamingo = "#f2cdcd";
        pink = "#f5c2e7";
        mauve = "#cba6f7";
        red = "#f38ba8";
        maroon = "#eba0ac";
        peach = "#fab387";
        yellow = "#f9e2af";
        green = "#a6e3a1";
        teal = "#94e2d5";
        sky = "#89dceb";
        sapphire = "#74c7ec";
        blue = "#89b4fa";
        lavender = "#b4befe";
        text = "#cdd6f4";
        subtext1 = "#bac2de";
        subtext0 = "#a6adc8";
        overlay2 = "#9399b2";
        overlay1 = "#7f849c";
        overlay0 = "#6c7086";
        surface2 = "#585b70";
        surface1 = "#45475a";
        surface0 = "#313244";
        base = "#1e1e2e";
        mantle = "#181825";
        crust = "#11111b";
      };

      add_newline = true;
      follow_symlinks = false;
      # 1 s per spawned module command, not the 5 s this used to allow.
      # What it does NOT cover, measured on 1.26: `git_status` runs in-process
      # with gitoxide — the only git subprocesses a prompt spawns are `git config`
      # and `git for-each-ref` — so this value cannot bound a slow status walk.
      # The NAS mount is handled by not running that module there at all
      # (`starship-no-git.toml` below); this keeps the commands that *are* spawned
      # from parking a prompt behind a hung mount.
      command_timeout = 1000;
      continuation_prompt = "[∙ ](dimmed overlay0)";

      format = lib.concatStrings [
        "$os"
        "$username"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_status"
        "$nix_shell"
        "$fill"
        "$cmd_duration"
        "$jobs"
        "$line_break"
        "$character"
      ];

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
        vimcmd_symbol = "[❮](bold lavender)";
        vimcmd_replace_one_symbol = "[❮](bold peach)";
        vimcmd_replace_symbol = "[❮](bold maroon)";
        vimcmd_visual_symbol = "[❮](bold yellow)";
      };

      os = {
        disabled = false;
        style = "bold blue";
        symbols = {
          NixOS = " ";
          Linux = "🐧 ";
          Macos = "🍎 ";
          Ubuntu = " ";
        };
      };

      username = {
        show_always = false;
        style_user = "bold lavender";
        style_root = "bold red";
        format = "[$user]($style)@";
      };

      hostname = {
        ssh_only = true;
        style = "bold mauve";
        format = "[$hostname]($style) in ";
      };

      directory = {
        home_symbol = "~";
        truncation_length = 3;
        truncation_symbol = "…/";
        truncate_to_repo = true;
        style = "bold blue";
        read_only = " 󰌾";
        read_only_style = "red";
        format = "[$path]($style)[$read_only]($read_only_style) ";
        repo_root_style = "bold sapphire";
      };

      git_branch = {
        symbol = " ";
        style = "bold mauve";
        format = "on [$symbol$branch]($style) ";
        truncation_length = 20;
        truncation_symbol = "…";
      };

      git_status = {
        # nixconfig carries submodules; walking each one is what pushes the
        # status call past the timeout on the NAS.
        ignore_submodules = true;
        style = "bold peach";
        format = "([$all_status$ahead_behind]($style) )";
        conflicted = "=";
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        untracked = "?";
        modified = "!";
        staged = "+";
        renamed = "»";
        deleted = "✘";
        stashed = "🪎";
      };

      nix_shell = {
        symbol = " ";
        style = "bold sky";
        format = "via [$symbol$state( \($name\))]($style) ";
        impure_msg = "impure";
        pure_msg = "pure";
        unknown_msg = "";
      };

      fill = {
        symbol = " ";
      };

      cmd_duration = {
        min_time = 2000;
        style = "italic subtext0";
        format = "[took $duration]($style)";
      };

      jobs = {
        symbol = "✦ ";
        style = "bold yellow";
        format = "[$symbol$number]($style) ";
      };
    };
  };

  # The one module that walks a worktree, projected out for the mounts where that
  # walk is a network round trip per directory. Generated from the real settings
  # so the two prompts can never drift; only `git_status` is dropped, so a NAS
  # repo still shows its branch. Selected per directory by STARSHIP_CONFIG
  # (bash hook: modules/shell/default.nix, nu hook: modules/config/nu/config.nu).
  home.file.".config/starship-no-git.toml".source = let
    settings = config.programs.starship.settings;
  in
    (pkgs.formats.toml {}).generate "starship-no-git.toml" (settings
      // {
        git_status = (settings.git_status or {}) // {disabled = true;};
      });
}
