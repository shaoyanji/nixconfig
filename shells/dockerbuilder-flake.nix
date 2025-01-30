{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    lib = nixpkgs.lib;
    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    forEachSupportedSystem = f: lib.genAttrs supportedSystems (system: f system);
    imageName = "tgpt";
    imageTag = "latest";
    mkDockerImage = pkgs: targetSystem: let
      archSuffix =
        if targetSystem == "x86_64-linux"
        then "amd64"
        else "arm64";
      #          duckgpt = pkgs.callPackage ./official.nix {};
      alpine = pkgs.dockerTools.pullImage {
        imageName = "alpine";
        imageDigest = "sha256:56fa17d2a7e7f168a043a2712e63aed1f8543aeafdcee47c58dcffe38ed51099";
        hash = "sha256-C3TOcLa18BKeBfS5FSe0H6BALGA/zXSwSZstK+VaPyo=";
        finalImageName = "alpine";
        finalImageTag = "latest";
      };
    in
      pkgs.dockerTools.buildImage {
        name = imageName;
        tag = "${imageTag}-${archSuffix}";
        fromImage = alpine;
        copyToRoot = pkgs.buildEnv {
          name = "image-root";
          paths = [pkgs.tgpt];
          pathsToLink = ["/bin"];
        };
        config = {
          EntryPoint = ["/bin/sh"];
        };
      };
  in {
    packages = forEachSupportedSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};

        buildForLinux = targetSystem:
          if system == targetSystem
          then mkDockerImage pkgs targetSystem
          else
            mkDockerImage (import nixpkgs {
              localSystem = system;
              crossSystem = targetSystem;
            })
            targetSystem;
      in {
        "amd64" = buildForLinux "x86_64-linux";
        "arm64" = buildForLinux "aarch64-linux";
      }
    );

    apps = forEachSupportedSystem (system: {
      default = {
        type = "app";
        program = toString (
          nixpkgs.legacyPackages.${system}.writeScript "build-multi-arch" ''
            #!${nixpkgs.legacyPackages.${system}.bash}/bin/bash
            set -e
            echo "Building x86_64-linux image..."
            nix build .#amd64 --out-link result-${system}-amd64
            echo "Building aarch64-linux image..."
            nix build .#arm64 --out-link result-${system}-arm64
          ''
        );
      };
    });
  };
}
