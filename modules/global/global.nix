{ pkgs, ... }: {
  nix = {
    gc = {
      automatic = true;
      options = "--delete-older-than 10d";
    };
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
      "pipe-operators"
    ];
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://nix-gaming.cachix.org"
      "https://cuda-maintainers.cachix.org"
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
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      # "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "shaoyanji.cachix.org-1:3XUZGFcaq5bXFKwtCR+POG81Hh6WfTqf50Bmz4VHpj0="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
    trusted-users = [
      "@admin"
      "@wheel"
    ];
  };

  nix = {
    package = pkgs.nixVersions.latest;
    optimise.automatic = true;
    extraOptions = ''
      min-free = ${toString (100 * 1024 * 1024)}
      max-free = ${toString (1024 * 1024 * 1024)}
    '';
    # nix.nixPath was renamed to nix.settings.nix-path (nixpkgs 26.11);
    # the old form emits a deprecation warning on every eval.
    settings.nix-path = [
      "nixpkgs=${pkgs.path}"
    ];
  };

  nixpkgs.config.allowUnfree = true;
}
