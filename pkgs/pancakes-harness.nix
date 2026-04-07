{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "pancakes-harness";
  version = "0.2.4";

  src = fetchFromGitHub {
    owner = "shaoyanji";
    repo = "pancakes-harness";
    rev = "v${version}";
    hash = "sha256-pMHJOkiBWmb7VqcmA/ExmF4I8FGk5g8va+DWBME80Ho=";
  };

  patches = [
    ./patches/pancakes-harness/xs-backend-integration.patch
  ];

  vendorHash = null;
  subPackages = [
    "cmd/harness"
    "cmd/demo-cli"
  ];

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "Local-first context and egress harness";
    homepage = "https://github.com/shaoyanji/pancakes-harness";
    license = licenses.mit;
    mainProgram = "harness";
    platforms = platforms.linux;
  };
}
