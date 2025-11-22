{pkgs, ...}: {
  home.packages = with pkgs; [
    # marksman
    dprint
    # gopls
    # alejandra
    # nixd
    # kdePackages.qtdeclarative
    # ruff
  ];
  programs.helix = {
    languages.language = [
      {
        name = "bash";
        indent = {
          tab-width = 4;
          unit = "    ";
        };
        formatter.command = "${pkgs.shfmt}/bin/shfmt";
        auto-format = true;
      }
      {
        name = "markdown";
        auto-format = true;
        formatter.command = "${pkgs.dprint}/bin/dprint";
        formatter.args = ["fmt" "--stdin" "md"];
      }
      {
        name = "haskell";
        auto-format = true;
        formatter.command = "${pkgs.stylish-haskell}/bin/stylish-haskell";
      }
      {
        name = "awk";
        formatter = {
          command = "${pkgs.gawk}/bin/awk";
          timeout = 5;
          args = ["--file=/dev/stdin" "--pretty-print=/dev/stdout"];
        };
      }
      {
        name = "toml";
        auto-format = true;
        formatter = {
          command = "${pkgs.taplo}/bin/taplo";
          args = ["format" "-"];
        };
      }
      {
        name = "python";
        auto-format = true;
        formatter = {
          command = "${pkgs.ruff}/bin/ruff";
          args = ["format" "--line-length" "88" "-"];
        };
      }
      {
        name = "qml";
        formatter = {
          command = "${pkgs.kdePackages.qtdeclarative}/bin/qmlls";
          args = ["-E"];
        };
      }
      {
        name = "lua";
        auto-format = true;
        formatter = {
          command = "${pkgs.stylua}/bin/stylua";
          args = ["-"];
        };
      }
      {
        name = "yaml";
        auto-format = true;
        formatter.command = "${pkgs.dprint}/bin/dprint";
        formatter.args = ["fmt" "--stdin" "yaml"];
      }
      {
        name = "go";
        auto-format = true;
        formatter.command = "${pkgs.gopls}/bin/gopls";
      }
      #{
      #  name = "c-sharp";
      #  auto-format = true;
      #  formatter.command = "${pkgs.omnisharp-roslyn}/bin/OmniSharp";
      #}
      {
        name = "nix";
        auto-format = true;
        formatter.command = "${pkgs.alejandra}/bin/alejandra";
      }
    ];

    enable = true;
    settings = {
      theme = "autumn_night_transparent";
      editor.cursor-shape = {
        normal = "block";
        insert = "bar";
        select = "underline";
      };
    };
    themes = {
      autumn_night_transparent = {
        "inherits" = "autumn_night";
        "ui.background" = {};
      };
    };
  };
}
