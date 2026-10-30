{
  description = "NixOS Build Tracker — Lambda + DynamoDB + Cognito, built by Nix, Always Free only";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {nixpkgs, ...}: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    eachSystem = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
  in {
    packages = eachSystem (pkgs: let
      sources = pkgs.lib.fileset.toSource {
        root = ./.;
        fileset = pkgs.lib.fileset.unions [./go.mod ./go.sum ./lambda];
      };

      binary = pkgs.buildGoModule {
        pname = "nix-build-tracker";
        version = "0.1.0";
        src = sources;
        subPackages = ["lambda"];
        vendorHash = "sha256-ztGZCkjYepnRBjjAqEGcezNL+a8K0p48vCmJ/ihx3q0=";
        # buildGoModule pins GOOS/GOARCH to the build host, so the Lambda target is
        # set in the phase that compiles: linux/amd64 from any host, byte for byte.
        # `go install` would also write a cross-compiled binary to bin/linux_amd64/,
        # hence the explicit -o.
        buildPhase = "true";
        installPhase = ''
          export CGO_ENABLED=0 GOOS=linux GOARCH=amd64
          runHook preInstall
          mkdir -p $out/bin
          go build -mod=vendor -trimpath -ldflags '-s -w' -o $out/bin/lambda ./lambda
          runHook postInstall
        '';
        meta.mainProgram = "lambda";
      };

      lambdaZip =
        pkgs.runCommand "nix-build-tracker-lambda.zip" {
          nativeBuildInputs = [pkgs.zip];
          meta.description = "Zip for AWS Lambda provided.al2023, statically linked linux/amd64";
        } ''
          mkdir -p pkg
          install -m755 ${binary}/bin/lambda pkg/bootstrap
          find pkg -exec touch -d @0 {} +
          (cd pkg && zip -q -X -r "$out" bootstrap)
        '';
    in {
      default = lambdaZip;
      lambda-zip = lambdaZip;
      lambda-binary = binary;
    });

    devShells = eachSystem (pkgs: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          awscli2
          go
          gopls
          jq
          zip
          unzip
          curl
          alejandra
        ];

        shellHook = ''
          echo "nix-build-tracker: aws $(aws --version 2>&1 | cut -d' ' -f1 | cut -d/ -f2), go $(go version | cut -d' ' -f3)"
          echo "  ./deploy.sh                 provision / update everything"
          echo "  nix build .#lambda-zip      the Lambda artifact, reproducibly"
        '';
      };
    });

    formatter = eachSystem (pkgs: pkgs.alejandra);
  };
}
