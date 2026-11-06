# deutsch-srs: the TUI that reviews the Anki collection on delphi
# (`-backend anki-sync`). Built from the release tag, not the prebuilt asset,
# so it exists on every arch this flake serves.
{
  lib,
  pkgs,
  ...
}: let
  version = "0.3.0";
in
  pkgs.buildGoModule {
    pname = "deutsch-srs";
    inherit version;

    src = pkgs.fetchFromGitHub {
      owner = "shaoyanji";
      repo = "deutsch-srs";
      rev = "v${version}";
      hash = "sha256-4eLJsFib6Cl1wTltZ/nCioo/oWTGuq9mbgnBXJxIfPw=";
    };

    vendorHash = "sha256-ZnYW1pKdV0yjKwvHz5JZJkwheK4WjCr6Ts3IQr+piJQ=";

    subPackages = ["cmd/deutsch-srs"];

    # SQLite is modernc.org/sqlite (pure Go) and the release binary is static,
    # which is what lets it run on a host with no glibc at all.
    env.CGO_ENABLED = 0;

    ldflags = [
      "-s"
      "-w"
      "-X github.com/shaoyanji/deutsch-srs/internal/version.Version=${version}"
      "-X github.com/shaoyanji/deutsch-srs/internal/version.Commit=v${version}"
    ];

    # The live sync test skips without credentials, so the rest still runs.
    doCheck = true;

    meta = {
      description = "Terminal spaced-repetition trainer, reading an Anki collection over the sync protocol";
      homepage = "https://github.com/shaoyanji/deutsch-srs";
      license = lib.licenses.mit;
      mainProgram = "deutsch-srs";
      platforms = lib.platforms.unix;
    };
  }
