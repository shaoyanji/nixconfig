# molly-brown from upstream master instead of nixpkgs' 2023-02-10 snapshot.
#
# Upstream (`tildegit.org/solderpunk/molly-brown`) publishes neither tags nor
# releases — both lists are empty, measured 2026-10-29 — so "the newest release"
# can only be the tip of master. The go module set has not moved since nixpkgs'
# pin: `vendorHash` here is the one already in nixpkgs, verified by building this
# override locally, so only `src` and `version` differ from stock.
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
