{
  description = "
    Linux + Nix (heim)
    MacOS + Nix (cassini)
    NixOS (poseidon, ares, schneeeule, applevalley, mtfuji, ancientace)
    NixOS HomeServer (thinsandy)
    aarch64 hm (kali)
    aarch NixOS (minyx)
    ChromeOS (penguin)
    WSL (guckloch)
  ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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
    nur = {
      url = "github:nix-community/NUR";
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

    dms = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
      # inputs.dgop.follows = "dgop";
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-openclaw = {
      url = "github:openclaw/nix-openclaw/f40ededb24d5db62b8b1894b20d891b852dc9a20";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-hermes = {
      url = "github:0xrsydn/nix-hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hermes-src = {
      url = "github:NousResearch/hermes-agent?submodules=1";
      flake = false;
    };
  };

  outputs = {self, nixpkgs, ...} @ inputs: let
    lib = nixpkgs.lib;
    systems = import ./flake/systems.nix {flake-utils = inputs.flake-utils;};
    pkgsFor = import ./flake/pkgs-for.nix {inherit nixpkgs;};
    mkNixosHost = import ./lib/mk-nixos-host.nix {inherit nixpkgs;};
    moduleSets = import ./flake/module-sets.nix {inherit inputs self;};
  in {
    packages = import ./flake/packages.nix {
      inherit lib systems pkgsFor;
    };

    checks = import ./flake/checks.nix {
      inherit lib systems pkgsFor self;
    };

    devShells = import ./flake/devshells.nix {
      inherit lib systems pkgsFor;
    };

    homeConfigurations = import ./flake/home-configurations.nix {
      inherit inputs moduleSets nixpkgs;
    };

    nixosConfigurations = import ./flake/nixos-configurations.nix {
      inherit inputs self mkNixosHost moduleSets;
    };

    darwinConfigurations = import ./flake/darwin-configurations.nix {
      inherit inputs moduleSets;
    };

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations.cassini.pkgs;
  };
}
