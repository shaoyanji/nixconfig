{pkgs, ...}: {
  home.packages = with pkgs; [
  ];
  home.file = {
    ".wezterm.lua".source = builtins.fetchUrl {
      url = "https://gist.githubusercontent.com/shaoyanji/48fff9824e79ceac6a07c67b05289dee/raw/10682f877a1832f8f08c89d4f07ac5427e607000/.wezterm.lua";
      sha256 = "0crl3fdmnag112i38zz0pxqyyrvw1waq1yaq30vv4jmlw8zq1w4i";
    };
  };
  xdg.configFile = {
    "wezterm/modules/mappings.lua".source = builtins.fetchUrl {
      url = "https://gist.githubusercontent.com/shaoyanji/f0ccea80f73f335cb3cbd46b5a0995e9/raw/3ab472b6575baf8b4f0b7619f1634911e313f87b/mappings.lua";
      sha256 = "0z3gnjphkl720qrm2ji2zgdzynbpb6xq2yq4wj934f7v7ay1hkg3";
    };
  };
}
