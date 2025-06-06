{pkgs, ...}: {
  home.packages = with pkgs; [
    marksman
    dprint
    gopls
  ];
  programs.helix = {
    enable = true;
    settings = {
      theme = "autumn_night_transparent";
      editor.cursor-shape = {
        normal = "block";
        insert = "bar";
        select = "underline";
      };
    };
    languages.language = [
      {
        name = "markdown";
        auto-format = true;
        formatter.command = "${pkgs.dprint}/bin/dprint";
        formatter.args = ["fmt" "--stdin" "md"];
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
    themes = {
      autumn_night_transparent = {
        "inherits" = "autumn_night";
        "ui.background" = {};
      };
    };
  };
}
