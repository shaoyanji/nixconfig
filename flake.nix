{
  description = "Working Darwin system flake using Determinate and SSL hack";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    nix-homebrew.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, 
		      home-manager, nixvim, sops-nix, ... }:
  let
    
    configuration = { pkgs, config, ... }: {
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      nixpkgs.config.allowUnsupportedSystem = true;
      nixpkgs.config.allowUnfree = true;
      environment.systemPackages = with pkgs;
	[
	  mkalias
	];

      homebrew = {
	enable = true;
	taps = [
	    #"krtirtho/apps"
	    #	"homebrew/cask-fonts"
	    #	"dart-lang/dart"
	    #	"homebrew/bundle"
	    #	"homebrew/services"
	];
	brews = [
	#	    "mas"
	];
	casks = [
		"arc"
		"orbstack"
	    #	"spotube"
	    #	"keybase"
	    #	"notion"
	    #	"raycast"
	    #	"slack"
	    #	"zoom"
	    #
	];
	masApps = {
	    #	"ISH" = 1436902243;
	    #   "Steamlink" = 1246969117;
	};
	onActivation.cleanup = "zap";
	onActivation.autoUpdate = true;
	onActivation.upgrade = true;
      };

      system.activationScripts.applications.text = let
  	env = pkgs.buildEnv {
    	 name = "system-applications";
    	 paths = config.environment.systemPackages;
    	 pathsToLink = "/Applications";
	};
      in
  	pkgs.lib.mkForce ''
  	# Set up applications.
  	echo "setting up /Applications..." >&2
  	rm -rf /Applications/Nix\ Apps
  	mkdir -p /Applications/Nix\ Apps
  	find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
  	while read src; do
    	 app_name=$(basename "$src")
    	 echo "copying $src" >&2
    	 ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
  	done
        '';
      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 5;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#
    darwinConfigurations."matts-MacBook-Air" = nix-darwin.lib.darwinSystem {
      specialArgs = { inherit inputs; };
      modules = [
	./configuration.nix 
      	configuration 
	nix-homebrew.darwinModules.nix-homebrew{
	 nix-homebrew = {
	  enable = true;
	  enableRosetta = true;
	  user = "devji";
	 };
	}
   	home-manager.darwinModules.home-manager
	{
	  home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.devji = import ./home.nix;
	  home-manager.sharedModules = [
	      	sops-nix.homeManagerModules.sops
	    ];
	  home-manager.extraSpecialArgs = { inherit inputs; }; # Pass inputs to homeManagerConfiguration
	  # Optionally, use home-manager.extraSpecialArgs to pass
	  users.users.devji= {
	    name = "devji";
	    home = "/Users/devji";
	  };
              # arguments to home.nix
        }
      ];
    };
    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."matts-MacBook-Air".pkgs;
  };
}
