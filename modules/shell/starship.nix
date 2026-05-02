{...}: {
  programs.starship = {
    enable = true;
    # Configuration written to ~/.config/starship.toml
    settings = {
      follow_symlinks = false;
      add_newline = false;
      command_timeout = 1300;
      scan_timeout = 50;
      continuation_prompt = "[▸▹ ](dimmed fg:white)";
      format = "($nix_shell$container$fill$git_metrics\n)$cmd_duration$hostname$localip$shlvl$shell$env_var$jobs$sudo$username$character";
      right_format = "$singularity$kubernetes$directory$vcsh$fossil_branch$git_branch$git_commit$git_state$git_status$hg_branch$pijul_channel$docker_context$package$c$cmake$cobol$daml$dart$deno$dotnet$elixir$elm$erlang$fennel$golang$guix_shell$haskell$haxe$helm$java$julia$kotlin$gradle$lua$nim$nodejs$ocaml$opa$perl$php$pulumi$purescript$python$raku$rlang$red$ruby$rust$scala$solidity$swift$terraform$vlang$vagrant$zig$buf$conda$meson$spack$memory_usage$aws$gcloud$openstack$azure$crystal$custom$status$os$battery$time";
      # format = "$all$nix_shell$nodejs$lua$golang$rust$php$git_branch$git_commit$git_state$git_status\n$username$hostname$directory";
      fill.symbol = " ";
      character = {
        format = "$symbol ";
        success_symbol = "[◎](bold italic fg:bright-yellow)";
        error_symbol = "[○](italic fg:purple)";
        vimcmd_symbol = "[■](italic dimmed fg:green)";
        # not supported in zsh;
        vimcmd_replace_one_symbol = "◌";
        vimcmd_replace_symbol = "□";
        vimcmd_visual_symbol = "▼";
        # success_symbol = "[➜](bold green)";
        # error_symbol = "[➜](bold red)";
      };
      directory = {
        home_symbol = "⌂";
        truncation_length = 2;
        truncation_symbol = "□ ";
        read_only = " ◈";
        use_os_path_sep = true;
        style = "italic fg:blue";
        format = "[$path]($style)[$read_only]($read_only_style)";
        repo_root_style = "bold fg:blue";
        repo_root_format = "[$before_root_path]($before_repo_root_style)[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) [△](bold fg:bright-blue)";
      };
      env_var.VIMSHELL = {
        format = "[$env_value]($style)";
        style = "fg:green italic";
      };
      sudo = {
        format = "[$symbol]($style)";
        style = "bold italic fg:bright-purple";
        symbol = "⋈┈";
        disabled = false;
      };
      username = {
        style_user = "fg:bright-yellow bold italic";
        style_root = "fg:purple bold italic";
        format = "[⭘ $user]($style) ";
        disabled = false;
        show_always = false;
      };
      cmd_duration = {
        min_time = 0;
        format = "[◄ $duration ](italic fg:white)";
      };
      jobs = {
        format = "[$symbol$number]($style) ";
        style = "fg:white";
        symbol = "[▶](fg:blue italic)";
      };
      localip = {
        ssh_only = true;
        format = " ◯[$localipv4](bold fg:magenta)";
        disabled = false;
      };
      time = {
        disabled = false;
        format = "[ $time]($style)";
        time_format = "%R";
        utc_time_offset = "local";
        style = "italic dimmed fg:white";
      };
      battery = {
        format = "[ $percentage $symbol]($style)";
        full_symbol = "█";
        charging_symbol = "[↑](italic bold fg:green)";
        discharging_symbol = "↓";
        unknown_symbol = "░";
        empty_symbol = "▃";
        # display = [20 60 70];
        # style = [
        # "italic bold red"
        # "italic dimmed bright-purple"
        # "italic dimmed yellow"
        # ];
      };
      git_branch = {
        format = " [$branch(:$remote_branch)]($style)";
        symbol = "[△](bold italic fg:bright-blue)";
        style = "italic fg:bright-blue";
        truncation_symbol = "⋯";
        truncation_length = 11;
        ignore_branches = ["main" "master"];
        only_attached = true;
      };
      git_metrics = {
        format = "([▴$added]($added_style))([▿$deleted]($deleted_style))";
        added_style = "italic dimmed fg:green";
        deleted_style = "italic dimmed fg:red";
        ignore_submodules = true;
        disabled = false;
      };
      git_status = {
        style = "bold italic fg:bright-blue";
        format = "([⎪$ahead_behind$staged$modified$untracked$renamed$deleted$conflicted$stashed⎥]($style))";
        conflicted = "[◪◦](italic fg:bright-magenta)";
        ahead = "[▴│[\${count}](bold fg:white)│](italic fg:green)";
        behind = "[▿│[\${count}](bold fg:white)│](italic fg:red)";
        diverged = "[◇ ▴┤[\${ahead_count}](regular fg:white)│▿┤[\${behind_count}](regular fg:white)│](italic fg:bright-magenta)";
        untracked = "[◌◦](italic fg:bright-yellow)";
        stashed = "[◃◈](italic fg:white)";
        modified = "[●◦](italic fg:yellow)";
        staged = "[▪┤[$count](bold fg:white)│](italic fg:cyan)";
        renamed = "[◎◦](italic fg:bright-blue)";
        deleted = "[✕](italic fg:red)";
      };
      memory_usage = {
        symbol = "▪▫▪ ";
        format = " mem [\${ram}( \${swap})]($style)";
        style = "fg:white";
      };
      aws = {
        disabled = true;
        format = " [aws](italic) [$symbol $profile $region]($style)";
        style = "bold fg:blue";
        symbol = "▲ ";
      };
      python = {
        format = " [py](italic) [\${symbol}\${version}]($style)";
        symbol = "[⌉](bold fg:bright-blue)⌊ ";
        version_format = "\${raw}";
        style = "bold fg:bright-yellow";
      };
      conda = {
        symbol = "◯ ";
        format = " conda [$symbol$environment]($style)";
        style = "fg:blue";
      };
      golang = {
        symbol = "∩ ";
        format = " go [$symbol($version )]($style)";
        style = "fg:cyan bold";
      };
      nix_shell = {
        style = "bold italic dimmed fg:blue";
        symbol = "✶";
        format = "[$symbol nix⎪$state⎪]($style) [$name](italic dimmed fg:white)";
        impure_msg = "[⌽](bold dimmed fg:red)";
        pure_msg = "[⌾](bold dimmed fg:green)";
        unknown_msg = "[◌](bold dimmed fg:yellow)";
      };
      lua = {
        format = " [lua](italic) [\${symbol}\${version}]($style)";
        version_format = "\${raw}";
        symbol = "⨀ ";
        style = "bold fg:bright-yellow";
      };
      nodejs = {
        format = " [node](italic) [◫ ($version)](bold fg:bright-green)";
        version_format = "\${raw}";
        detect_files = ["package-lock.json" "yarn.lock"];
        detect_folders = ["node_modules"];
        detect_extensions = [];
      };
      # package.disabled = true;
    };
  };
}
