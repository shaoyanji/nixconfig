{
  description = "Personal Nix configuration: NixOS, nix-darwin, and Home Manager";

  # Prebuilt packages and LAN caches: ensure any flake evaluation carries
  # the binary caches for llm-agents.nix and local store transfers.
  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
      # Determinate Nix's own cache. Its CLI is not on cache.nixos.org, so
      # without this every CI/build of a fleet host compiles 54 derivations
      # (boost, wasmtime, libgit2) instead of fetching DN.
      "https://install.determinate.systems"
      "http://100.97.61.65:5000"
      "http://192.168.3.25:5000"
      "http://192.168.3.98:5000"
    ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "frieren.lan-1:BUg+1UmfYlF0XCbC0+ZyWQOY1DpQJhj/wa2q76NTFOg="
    ];
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Determinate Nix — imported by modules/global/determinate-nix.nix, which
    # every NixOS chain carries since 2026-10-19. Do NOT make its nixpkgs
    # follow ours: the DN CLI and determinate-nixd come from its own locked
    # inputs and must stay upstream-compatible with the Nix it distributes.
    determinate.url = "github:DeterminateSystems/determinate";
    # AI coding-agent packages, auto-updated daily upstream.
    # follows is safe here: we track current nixpkgs-unstable, which is
    # what the flake builds against (stable branches WILL break it).
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
    };
    # MCP server packages + module framework (Zed context_servers pilot:
    # github + nixos servers — see modules/user/ai/zed-mcp.nix).
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    # chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    # caelestia = {
    #   url = "git+https://github.com/caelestia-dots/shell/";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    kickstart-nixvim.url = "github:shaoyanji/kickstart.nixvim";
    kickstart-nixvim.inputs.nixpkgs.follows = "nixpkgs";
    garnix-lib.url = "github:garnix-io/garnix-lib";
    # nixgl.url = "github:nix-community/nixGL";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    # dgop = {
    #   url = "github:AvengeMedia/dgop";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # The greeter lives in its own repo since 2026-09 (imported via
    # module-sets as inputs.dank-greeter.nixosModules.default →
    # programs.dms-greeter). See danklinux.com/docs/dankgreeter/nixos-flake.
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
      # inputs.dgop.follows = "dgop";
    };
    dank-greeter = {
      url = "github:AvengeMedia/dank-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bountystash = {
      url = "github:shaoyanji/bountystash";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    ...
  }:
    import ./flake/outputs.nix {
      inherit inputs self nixpkgs;
    };
}
