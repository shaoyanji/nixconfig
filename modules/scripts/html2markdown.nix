# html2markdown (Go): converts a text/html mail body into text, for the importer
# and `checks:email:bodies`. Vendored buildGoModule, static binary.
# docs: docs/email-archive.md
{pkgs}: let
  inherit (pkgs) lib;
in
  pkgs.buildGoModule rec {
    pname = "html2markdown";
    version = "2.5.2";

    src = pkgs.fetchFromGitHub {
      owner = "JohannesKaufmann";
      repo = "html-to-markdown";
      tag = "v${version}";
      hash = "sha256-Ay2ICo+zhVDLX8fpAfc+8/YrLGRCD9swDjAQHiA9+Eg=";
    };

    # Only the CLI; the library packages would otherwise pull the whole tree
    # into the output.
    subPackages = ["cli/html2markdown"];
    vendorHash = "sha256-/7Rm01pzjIZ31wxH5mjqGpojFX5GZknjRnFKPrr4JF4=";

    meta = {
      description = "Convert HTML into Markdown (CLI)";
      homepage = "https://github.com/JohannesKaufmann/html-to-markdown";
      license = lib.licenses.mit;
      mainProgram = "html2markdown";
    };
  }
