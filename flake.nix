{
  description = "Personal Nix configuration: NixOS, nix-darwin, and Home Manager";

  # Binary caches for the EVALUATION itself (a `nix build`/`nix develop` of this
  # flake), as opposed to nix.settings.substituters on a host, which
  # lib/cache-policy.nix compiles per host. The URLs and keys live in
  # lib/cache-registry.nix and nothing here repeats them; only the order does,
  # because evaluation asks each cache in turn and a LAN host must see harmonia
  # first. Determinate's cache is here because its CLI is not on cache.nixos.org:
  # without it every build of a fleet host compiles 54 derivations (boost,
  # wasmtime, libgit2) instead of fetching DN.
  # LITERAL on purpose. Determinate's flake reader rejects a computed value here
  # ("flake configuration setting 'extra-substituters' is a thunk"), so this list
  # cannot be derived from lib/cache-registry.nix. It is a copy WITH A GATE:
  # `checks.<system>.cache-registry` fails if the two ever disagree, in either
  # direction, so it cannot drift the way the hand-written list did.
  nixConfig = {
    extra-substituters = [
      "http://192.168.3.25:5000"
      "http://100.97.61.65:5000"
      "https://shaoyanji.cachix.org"
      "https://nix-community.cachix.org"
      "https://nix-gaming.cachix.org"
      "https://cache.numtide.com"
      "https://install.determinate.systems"
      "https://cache.nixos.org/"
    ];
    extra-trusted-public-keys = [
      "frieren.lan-1:BUg+1UmfYlF0XCbC0+ZyWQOY1DpQJhj/wa2q76NTFOg="
      "shaoyanji.cachix.org-1:3XUZGFcaq5bXFKwtCR+POG81Hh6WfTqf50Bmz4VHpj0="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # No pinned nixpkgs: netbook followed `nixpkgs` from 2026-10-22, and what it
    # pins instead is the initrd implementation (`boot.initrd.systemd.enable =
    # false`) — the reason and the boot test are in
    # `.agents/deploy/hosts/netbook.md`. The `nixpkgs_25_11` input that used to
    # carry this host was pruned from `flake.nix` and `flake.lock` once unused.
    # Determinate Nix — imported by modules/global/determinate-nix.nix, which
    # every NixOS chain carries since 2026-10-19. Do NOT make its nixpkgs
    # follow ours: the DN CLI and determinate-nixd come from its own locked
    # inputs and must stay upstream-compatible with the Nix it distributes.
    determinate.url = "github:DeterminateSystems/determinate";
    # AI coding-agent packages, auto-updated daily upstream.
    # nixpkgs is deliberately its OWN: llm-agents is built against
    # nixpkgs-unstable and a stable branch WILL break it. flake-parts follows
    # the root, because that is a build tool, not an API surface.
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.flake-parts.follows = "flake-parts";
    };
    # MCP server packages + module framework (Zed context_servers pilot:
    # github + nixos servers — see modules/user/ai/zed-mcp.nix).
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "flake-compat";
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
    # Flake plumbing that several inputs each pinned their own copy of (three
    # identical flake-compat nodes, three identical flake-parts nodes). Declaring
    # them at the root and following from the consumers collapses the duplicates;
    # it is a no-op for behaviour because the revs were already identical.
    # Determinate's own `nix` input keeps its flake-parts: that graph is
    # deliberately upstream-locked (see modules/global/determinate-nix.nix).
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-compat.url = "github:edolstra/flake-compat";
    kickstart-nixvim.url = "github:shaoyanji/kickstart.nixvim";
    kickstart-nixvim.inputs.nixpkgs.follows = "nixpkgs";
    kickstart-nixvim.inputs.flake-parts.follows = "flake-parts";
    kickstart-nixvim.inputs.nixvim.inputs.flake-parts.follows = "flake-parts";
    garnix-lib.url = "github:garnix-io/garnix-lib";
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
      inputs.flake-compat.follows = "flake-compat";
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
