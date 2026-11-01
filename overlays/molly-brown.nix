# molly-brown from upstream master: no tags or releases exist upstream (both lists
# empty, measured 2026-10-29), so master is the only "newest", and `vendorHash` is
# nixpkgs' own — only `src` and `version` differ. docs/nix-patterns.md (no tags).
_: prev: {
  molly-brown = prev.molly-brown.overrideAttrs (_: {
    version = "0-unstable-2026-05-25";
    src = prev.fetchgit {
      url = "https://tildegit.org/solderpunk/molly-brown";
      rev = "9627852ac6937a655216109980cef5da89fd16b2";
      hash = "sha256-OB408SNJb8XLWVooEt+ExiR8ejFart+Ssq2EVQdsXJg=";
    };
  });
}
