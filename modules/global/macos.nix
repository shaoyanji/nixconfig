{ config, pkgs,nix-homebrew, home-manager, inputs, ... }:

{

	  home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.devji = import ./home.nix;
	  home-manager.sharedModules = [
	      #  sops-nix.homeManagerModules.sops
	    ];
	  home-manager.extraSpecialArgs = { inherit inputs; }; # Pass inputs to homeManagerConfiguration
	  # Optionally, use home-manager.extraSpecialArgs to pass
	  users.users.devji= {
	    name = "devji";
	    home = "/Users/devji";
	  };
              # arguments to home.nix
	nix-homebrew = {
	  enable = true;
	  enableRosetta = true;
	  user = "devji";
	 };
}

