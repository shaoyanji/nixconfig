{ pkgs, ... }: {
  nix = {
    gc = {
      automatic = true;
      options = "--delete-older-than 10d";
    };
  };

  nix.settings = {
    # LAN binary cache served by harmonia on frieren (the NAS). Checked
    # first so hosts that share a LAN fetch store paths from each other
    # instead of the WAN caches.
    substituters = [
      "http://192.168.3.25:5000"
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://nix-gaming.cachix.org"
      # "https://cache.garnix.io"
      "https://shaoyanji.cachix.org"
      # Prebuilt AI-agent packages from llm-agents.nix (crush, freebuff,
      # qmd, qwen-code, ...). Registered daemon-level so untrusted
      # clients (CI, sandboxed shells) hit it too — flake-level nixConfig
      # is silently ignored for users not in trusted-users.
      "https://cache.numtide.com"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      # "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "shaoyanji.cachix.org-1:3XUZGFcaq5bXFKwtCR+POG81Hh6WfTqf50Bmz4VHpj0="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "frieren.lan-1:BUg+1UmfYlF0XCbC0+ZyWQOY1DpQJhj/wa2q76NTFOg="
    ];
    trusted-users = [
      "@admin"
      "@wheel"
    ];
    experimental-features = [ "nix-command" "flakes" "pipe-operators" ];
    # Pre-trust the fleet caches so flake-level nixConfig (the
    # extra-substituters in flake.nix) never triggers the interactive
    # "allow configuration setting" y/N prompt on any fleet host.
    trusted-substituters = [
      "http://192.168.3.25:5000"
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://nix-gaming.cachix.org"
      "https://shaoyanji.cachix.org"
      "https://cache.numtide.com"
    ];
    # Fail over to the next substituter quickly instead of hanging on a
    # dead/unreachable cache, and fall back to local builds when no cache
    # can be reached.
    connect-timeout = 5;
    fallback = true;
    # Keep dev-shell closures out of GC so shells don't re-download
    # everything after a collection sweep.
    keep-outputs = true;
    # nix.nixPath was renamed to nix.settings.nix-path; the old form
    # emits a deprecation warning on every eval. Kept in this block:
    # a second `nix = { settings... }` is a duplicate-attribute error.
    nix-path = [
      "nixpkgs=${pkgs.path}"
    ];
  };

  nix = {
    package = pkgs.nixVersions.latest;
    optimise.automatic = true;
    extraOptions = ''
      min-free = ${toString (100 * 1024 * 1024)}
      max-free = ${toString (1024 * 1024 * 1024)}
    '';
  };

  nixpkgs.config.allowUnfree = true;
}
