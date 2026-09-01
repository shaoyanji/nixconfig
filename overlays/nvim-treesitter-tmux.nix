# Re-add the `tmux` tree-sitter grammar to `nvim-treesitter.builtGrammars`.
#
# nvim-treesitter upstream dropped the tmux grammar (generated.nix no longer
# contains it), which breaks the pinned kickstart-nixvim fork: its
# `config/plugins/kickstart/treesitter.nix` references `tmux` via
# `with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [ ... ]`.
#
# Same definition the previous nixpkgs rev shipped:
#   tmux = buildGrammar {
#     language = "tmux";
#     version = "0.0.0+rev=75d1b99";
#     src = fetchFromGitHub { owner = "Freed-Wu"; repo = "tree-sitter-tmux"; ... };
#   };
_final: prev: {
  vimPlugins =
    prev.vimPlugins
    // {
      nvim-treesitter = prev.vimPlugins.nvim-treesitter.overrideAttrs (oldAttrs: {
        passthru =
          (oldAttrs.passthru or {})
          // {
            builtGrammars =
              (oldAttrs.passthru.builtGrammars or {})
              // {
                tmux = prev.tree-sitter.buildGrammar {
                  language = "tmux";
                  version = "0.0.0+rev=75d1b99";
                  src = prev.fetchFromGitHub {
                    owner = "Freed-Wu";
                    repo = "tree-sitter-tmux";
                    rev = "75d1b995b0c23400ac8e49db757a2e0386f9fa8f";
                    hash = "sha256-LdXPdijcsfPYIrbTMDIy46wqOaJfxwVBVpOVVfXrJIg=";
                  };
                  meta.homepage = "https://github.com/Freed-Wu/tree-sitter-tmux";
                };
              };
          };
      });
    };
}
