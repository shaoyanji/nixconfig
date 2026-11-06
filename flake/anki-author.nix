# anki-author: TOML → .anki2/.apkg. Authoring only; reviewing is deutsch-srs
# and storage is the sync server on delphi.
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "anki-author";
  runtimeInputs = [pkgs.python3];
  text = ''
    exec ${pkgs.python3}/bin/python3 ${../scripts/german/anki-author.py} "$@"
  '';
}
