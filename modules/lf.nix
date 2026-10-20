{pkgs, ...}: {
  # pkgs.fetchurl, not builtins.fetchurl: the builtin fetches during EVAL, so
  # every host whose store lacks this path needs GitHub to evaluate its config,
  # and the result cannot be substituted. A fixed-output derivation moves the
  # fetch to build time and keeps evaluation offline-safe.
  xdg.configFile."lf/icons".source = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/gokcehan/lf/refs/heads/master/etc/icons.example";
    hash = "sha256:12cwy6kfa2wj7nzffaxn5bka21yjqa5sx38nzdhyg1dq0c6jnjkk";
  };

  programs.lf = {
    enable = true;
    commands = {
      #      dragon-out = ''%${pkgs.xdragon}/bin/xdragon -a -x "$fx"'';
      editor-open = ''$$EDITOR "$f"'';
      mkdir = ''
        ''${{
          printf "Directory Name: "
          read -r DIR
          mkdir -- "$DIR"
        }}
      '';
    };

    keybindings = {
      # lf key names are literal, so `"\\\""` bound the sequence \\ then "
      # rather than unbinding " — which is never bound by default anyway, but
      # null is the documented way and it cannot be misread.
      "\"" = null;
      o = "";
      c = "mkdir";
      "." = "set hidden!";
      "`" = "mark-load";
      # ' is mark-load by default; the old "\\'" line mapped \\ then ', not '.
      "<enter>" = "open";

      #     do = "dragon-out";

      "g~" = "cd";
      gh = "cd";
      "g/" = "/";

      ee = "editor-open";
      V = ''$'${pkgs.bat}'/bin/bat --paging=always --theme=gruvbox "$f"'';

      # ...
    };

    settings = {
      preview = true;
      hidden = true;
      drawbox = true;
      icons = true;
      ignorecase = true;
    };

    extraConfig = let
      previewer = pkgs.writeShellScriptBin "pv.sh" ''
        file=$1
        w=$2
        h=$3
        x=$4
        y=$5

        mime="$(${pkgs.file}/bin/file -Lb --mime-type "$file")"

        # icat paints straight onto the terminal, so it only makes sense inside
        # kitty. Anywhere else (wezterm, tmux without passthrough) fall through
        # to pistol instead of leaving the pane blank behind a failed icat.
        # `exit 1` is lf's signal to skip the preview cache — what a direct-draw
        # preview needs; it is only reached when icat actually succeeded.
        if [[ -n "''${KITTY_WINDOW_ID:-}" && "$mime" =~ ^image ]]; then
          if ${pkgs.kitty}/bin/kitty +kitten icat --silent --stdin no \
            --transfer-mode file --place "''${w}x''${h}@''${x}x''${y}" "$file" \
            < /dev/null > /dev/tty; then
            exit 1
          fi
        fi

        ${pkgs.pistol}/bin/pistol "$file"
      '';
      cleaner = pkgs.writeShellScriptBin "clean.sh" ''
        # Nothing was drawn outside kitty, and calling kitty there would spray
        # "command not found" over the terminal on every preview change.
        if [[ -n "''${KITTY_WINDOW_ID:-}" ]]; then
          ${pkgs.kitty}/bin/kitty +kitten icat --clear --stdin no --silent \
            --transfer-mode file < /dev/null > /dev/tty
        fi
      '';
    in ''
      set cleaner ${cleaner}/bin/clean.sh
      set previewer ${previewer}/bin/pv.sh
    '';
  };

  home.packages = with pkgs; [
    #dragon
    file
    bat
  ];
}
