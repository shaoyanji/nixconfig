# The fleet's binary caches: URL, public key, and `evalOrder` — the one judgement
# this file makes, namely which cache the flake's own evaluation asks first (a LAN
# host must see harmonia first). `key = null` mirrors the cache's own key.
{
  caches = {
    harmonia = {
      url = "http://192.168.3.25:5000";
      key = "frieren.lan-1:BUg+1UmfYlF0XCbC0+ZyWQOY1DpQJhj/wa2q76NTFOg=";
      role = "lan";
    };
    # The same harmonia over the tailnet, for a host evaluating this flake where
    # the LAN route does not exist. Not in any host's substituter order: a LAN
    # host must not fetch its own cache over the tailnet, and a cloud host gets
    # the same bytes more cheaply from cachix.
    harmoniaTailnet = {
      url = "http://100.97.61.65:5000";
      key = null;
      role = "lan";
    };
    cachix = {
      url = "https://shaoyanji.cachix.org";
      key = "shaoyanji.cachix.org-1:3XUZGFcaq5bXFKwtCR+POG81Hh6WfTqf50Bmz4VHpj0=";
      role = "wan";
    };
    nixos = {
      url = "https://cache.nixos.org/";
      key = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
      role = "upstream";
    };
    numtide = {
      url = "https://cache.numtide.com";
      key = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
      role = "upstream";
    };
    nixCommunity = {
      url = "https://nix-community.cachix.org";
      key = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
      role = "community";
    };
    nixGaming = {
      url = "https://nix-gaming.cachix.org";
      key = "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=";
      role = "community";
    };
    determinate = {
      url = "https://install.determinate.systems";
      key = "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM=";
      role = "upstream";
    };
  };

  evalOrder = [
    "harmonia"
    "harmoniaTailnet"
    "cachix"
    "nixCommunity"
    "nixGaming"
    "numtide"
    "determinate"
    "nixos"
  ];
}
