# gemini.frieren.lan — the fleet documentation as a Gemini capsule.
#
# One projection, not a second tree: the pages are the same markdown the docs
# artifact (`.#artifacts.docs`) and the HTTP site are built from, converted to
# gemtext by lib/gemtext.nix. The certificate is the existing `*.frieren.lan`
# wildcard, so nothing new is issued and no ACME path is involved.
{
  config,
  lib,
  pkgs,
  ...
}: let
  root = ../..;

  # The same compiler the docs artifact uses, so the capsule and the site cannot
  # disagree about the fleet.
  docs = import ../../lib/docs.nix {
    inherit lib;
    inherit (config.fleet) inventory;
  };

  readRepo = path: builtins.readFile (root + "/${path}");

  repodocs = lib.mapAttrs' (name: _: lib.nameValuePair "docs/${name}" (readRepo "docs/${name}")) (
    lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".md" name) (builtins.readDir (root + "/docs"))
  );

  pages =
    docs.generatedPages
    // repodocs
    // {
      "README.md" = readRepo "README.md";
      "AGENTS.md" = readRepo "AGENTS.md";
    };
in {
  services.molly-brown = {
    enable = true;
    port = 1965;
    hostName = "gemini.frieren.lan";
    certPath = ../../modules/config/tls/frieren-lan-wildcard.pem;
    keyPath = "/run/secrets/tls-frieren-wildcard-key";

    docBase = import ../../lib/gemtext.nix {
      inherit lib pkgs pages;
      title = "fleet.frieren.lan";
      description = "The fleet's own documentation over Gemini: host inventory, module registry, runbooks and the project manual.";
      cgi.hello = ''
        printf '20 text/gemini\r\n'
        printf '# CGI is wired\n\n'
        printf 'This script is a file in the capsule store path, executed by the server user.\n\n'
        printf 'query:    %s\n' "''${QUERY_STRING:-<none>}"
        printf 'path:     %s\n' "''${PATH_INFO:-<none>}"
        printf 'from:     %s\n' "''${REMOTE_ADDR:-<unknown>}"
        printf 'server:   %s:%s\n' "''${SERVER_NAME:-?}" "''${SERVER_PORT:-?}"
      '';
    };

    # This MUST be relative: config.go joins a relative entry to DocBase but
    # leaves an absolute one alone, and the dispatch compares it against the
    # resolved filesystem path (which is under DocBase) — an absolute
    # "/cgi-bin" would never match. A request for /cgi-bin/<name> resolves to
    # <DocBase>/cgi-bin/<name>, which is the prefix this becomes.
    settings.CGIPaths = ["cgi-bin"];
  };

  # The wildcard key is 0400 nginx; joining that group keeps the secret
  # owner-only instead of widening it to world-readable.
  systemd.services.molly-brown.serviceConfig.SupplementaryGroups = ["nginx"];
}
