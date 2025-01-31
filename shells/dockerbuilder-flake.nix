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
    registryprefix="ghcr.io/shaoyanji/";
    imageName = "tgpt";
    imageTag = "latest";
    mkDockerImage = pkgs: targetSystem: let
      archSuffix =
        if targetSystem == "x86_64-linux"
        then "amd64"
        else "arm64";
      #          duckgpt = pkgs.callPackage ./official.nix {};
      alpine = pkgs.dockerTools.pullImage{
  imageName = "alpine";
  imageDigest = "sha256:115729ec5cb049ba6359c3ab005ac742012d92bbaa5b8bc1a878f1e8f62c0cb8";
  hash = "sha256-7E9mkUfYsv3Tzl99ggihTOFCqvcLB4/NsPyRUC1nqug=";
  finalImageName = "alpine";
  finalImageTag = "edge";
};
    in
      pkgs.dockerTools.buildImage {
        name = "${registryprefix}${imageName}";
        tag = "${imageTag}-${archSuffix}";
        fromImage = alpine;
        copyToRoot = pkgs.buildEnv {
          name = "image-root";
          paths = [pkgs.tgpt pkgs.bashInteractive pkgs.busybox];
          pathsToLink = ["/bin"];
        };
        config = {
          EntryPoint = ["/bin/bash"];
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
