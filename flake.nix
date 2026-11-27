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
      "https://nix-cache-edge.jisifu.workers.dev"
      "https://nix-community.cachix.org"
      "https://nix-gaming.cachix.org"
      "https://cache.numtide.com"
      "https://install.determinate.systems"
      "https://cache.nixos.org/"
    ];
    extra-trusted-public-keys = [
      "frieren.lan-1:BUg+1UmfYlF0XCbC0+ZyWQOY1DpQJhj/wa2q76NTFOg="
      "shaoyanji.cachix.org-1:3XUZGFcaq5bXFKwtCR+POG81Hh6WfTqf50Bmz4VHpj0="
      "delphi.edge-1:SAQXl68hP2k5mhlWOIXCyQXFD1rVelBB22oTKQkFzwk="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # kernel+driver pin via `nvidiaPkgs` (flake/module-sets.nix): bump with
    # `nix flake update nixpkgs-nvidia`; pinned at the rev the fleet ran.
    nixpkgs-nvidia.url = "github:NixOS/nixpkgs/e21fec321d73511849707a7585e4ea155ee4bf40";
    # nginx 1.30.7 CVE pin while `nixpkgs` < fix (hosts/*/reverse-proxy.nix).
    nixpkgs-nginx.url = "github:NixOS/nixpkgs/93a9ed0a866099a230ed5146a5bb7d16fd5c9b14";
    # Netbook's nixpkgs pin, revived: scripted initrd was REMOVED upstream
    # (`boot.initrd.systemd.enable` is now mkRemovedOptionModule), and the
    # scripted stage-1 is the only variant this eMMC boots (gen 50 vs 51 in
    # `.agents/deploy/hosts/netbook.md`). Pinned at c5c4a43 — the fleet nixpkgs
    # the last working generation built on — until systemd-initrd is proven on
    # the hardware. Consumed via `host.nixpkgs` in flake/host-inventory.nix.
    nixpkgs-netbook.url = "github:NixOS/nixpkgs/c5c4a43b0e8056328ec4529f735cabdb8f1942bb";
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
    # iets — numtide's Nix client, whose eval cache traces the files an eval
    # reads, so a warm `iets eval` answers a flake attribute in ~25 ms where
    # `nix eval` spends 0.15-1.7 s and never answers from cache. Used by the
    # knowledge-graph reads (scripts/task/lib/iets.sh); not a build path — it
    # ignores a flake's nixConfig, so substituters would be lost — see
    # docs/nix-patterns.md §"The eval the graph reads".
    iets = {
      url = "github:numtide/iets";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
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

    # DMS 2.0 is Dux Shell: Dank Linux rebranded to Dux Labs on 2026-10-20, and
    # the greeter moved to its own repo in 2026-09 (imported via module-sets as
    # inputs.dank-greeter.nixosModules.default → programs.dms-greeter). Both keep
    # their old flake output and option names (`nixosModules.dank-material-shell`,
    # `programs.dank-material-shell`) so the consumers needed only a URL bump.
    # one qml-common pin for dms + dank-greeter; flake/policies.nix#nix-comments-are-pointers
    dank-qml-common = {
      url = "github:duxlabs-dev/dux-qml-common";
      flake = false;
    };
    dms = {
      url = "github:duxlabs-dev/dux-shell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "flake-compat";
      inputs.dank-qml-common.follows = "dank-qml-common";
    };
    dank-greeter = {
      url = "github:duxlabs-dev/dux-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.dank-qml-common.follows = "dank-qml-common";
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

  # flake-parts is the assembly root, not a framework layered on top: it owns the
  # `outputs` function, `perSystem` builds the dev shells, and the flake's
  # attribute names come from one `flake` attribute. That attribute is the same
  # projection `flake/outputs.nix` evaluated before this change, which is the
  # point — the wiring moves, the outputs do not.
  #
  # `.#nixFiles` and `.#modules` (flake/nix-registry.nix) are the named module
  # tree: every tracked `.nix` file by path, and every file under `modules/` by
  # the name an import uses, walked from the files instead of listed. Chains,
  # hosts and modules import through it, so following an edge is a graph query
  # (`ops:kg:module`) rather than a grep for a relative path. Record:
  # `dendritic-flake` in AGENTS.nix.
  outputs = inputs @ {
    self,
    nixpkgs,
    ...
  }: let
    projected = import ./flake/outputs.nix {
      inherit inputs self nixpkgs;
    };
    systemsCtl = import ./flake/systems.nix {inherit nixpkgs;};
  in
    # The artifact namespaces are nested (`.#artifacts.docs`, `.#cli.ai.vox` and
    # their siblings), so they live in `legacyPackages`: the `packages` schema is
    # one flat level of derivations, while the nested tree is exactly what
    # `legacyPackages` exists to carry. The `.#` installables stay unchanged.
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = systemsCtl.systems.work;
      # Dev shells are `perSystem`'s business: one body, fanned out to the
      # declared systems by flake-parts instead of by a hand-written genAttrs.
      perSystem = {system, ...}: {
        devShells = import ./flake/devshells.nix {
          pkgs = systemsCtl.pkgsFor system;
          # `self` for the module registry: a shell is addressed by the name every
          # other import uses (`self.modules."config.shells.flaskpy"`) instead of
          # a path assembled in one more file.
          inherit self;
          root = ./.;
        };
      };
      flake = projected;
    };
}
