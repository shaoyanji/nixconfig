# wiki-ask — gated fan-out retrieval over the local ZIM archives.
#
# The engine already exists (kiwix-serve's Xapian index plus kiwix-search); this
# wrapper adds the three things the archive cannot do for itself: query
# relaxation (Xapian ANDs its terms, so a five-word incident query returns zero
# titles), cross-archive fusion, and a token gate so an agent gets ~300 tokens
# of the section that matched instead of ten titles or a whole article.
#
# Measured against `wikisearch` on frieren 2026-11-04: `wikisearch "btrfs scrub
# repair EIO"` returns F2FS; `wiki-ask` returns Btrfs → "Checking and recovery"
# in ~0.3 s. The gap is the fan-out, not the index.
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "wiki-ask";
  # `toon` is deliberately absent: `--toon` resolves it from the caller's PATH
  # (it is system-wide on frieren), and the task pipes JSON through `toon -e`
  # instead, which keeps the wire format JSON
  # ([[flake/policies.nix#agent-boundary-is-toon]]).
  runtimeInputs = with pkgs; [python3 kiwix-tools coreutils];
  text = ''
    exec python3 ${./wiki-ask.py} "$@"
  '';
}
