{lib, ...}: {
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
      # Repos that live on the NAS (/Volumes/data, NFS from a client) answer
      # `git status` in seconds, not milliseconds: at the 1000 ms default Starship
      # aborts with "Executing command \"git\" timed out" on every prompt there.
      # 5 s is below a human noticing a slow prompt, above a cold NFS lookup.
      command_timeout = 5000;
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
        stashed = "\$\$"; # escaped: every git_status symbol is a format string
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
}
