{pkgs, ...}: {
  home.packages = with pkgs; [
  ];
  home.file = {
    ".wezterm.lua".source = builtins.fetchurl {
      url = "https://gist.githubusercontent.com/shaoyanji/48fff9824e79ceac6a07c67b05289dee/raw/7703acd1e06466ddc9e954688a52f7772de55ac0/.wezterm.lua";
      sha256 = "1agjhyv428al1kz01rw2wz66w516pm7pxchvi5lz9kyw0qh7br9j";
    };
  };
  xdg.configFile = {
    "wezterm/modules/mappings.lua".source = builtins.fetchurl {
      url = "https://gist.githubusercontent.com/shaoyanji/f0ccea80f73f335cb3cbd46b5a0995e9/raw/3ab472b6575baf8b4f0b7619f1634911e313f87b/mappings.lua";
      sha256 = "0z3gnjphkl720qrm2ji2zgdzynbpb6xq2yq4wj934f7v7ay1hkg3";
    };
  };
}
