{
  lib,
  pkgs,
  ...
}: let
  nu-run = pkgs.writeShellApplication {
    name = "nu-run";
    runtimeInputs = [pkgs.nushell];
    text = ''
      exec nu \
        --config "''${XDG_CONFIG_HOME:-$HOME/.config}/nushell/config.nu" \
        --env-config "''${XDG_CONFIG_HOME:-$HOME/.config}/nushell/env.nu" \
        "$@"
    '';
  };

  # Ephemeral invocation wrappers for optional external binaries called by Nushell modules
  # (typst/pdfcpu in jobby.nu, todoist in utils.nu, html2markdown in utils.nu).
  # If the binary is already installed on PATH outside this wrapper, invoke it directly;
  # otherwise launch on-demand via ephemeral nix shell without bloating the host closure.
  mkLazyNixRun = name: pkg: bin:
    pkgs.writeShellScriptBin name ''
      exec nix shell "nixpkgs#${pkg}" -c "${bin}" "$@"
    '';

  lazyWrappers = [
    (mkLazyNixRun "typst" "typst" "typst")
    (mkLazyNixRun "pdfcpu" "pdfcpu" "pdfcpu")
    (mkLazyNixRun "todoist" "todoist" "todoist")
    (mkLazyNixRun "html2markdown" "html2text" "html2text")
  ];
in {
  programs = {
    nushell = {
      enable = true;

      # Stage 1: env.nu — executed first for PATH & session environment
      extraEnv = ''
        $env.PATH = (
          $env.PATH
            | split row (char esep)
            | prepend ~/.nix-profile/bin
            | append /usr/bin/env
        )

        # In-memory cached secrets loader (sub-millisecond warm starts)
        source ${../config/secrets.nu}
      '';

      # Stage 2: config.nu — executed second for UI, completions, hooks, modules.
      # The UI/history/completion settings are a real `.nu` file (they are
      # nushell, not Nix); what stays here is only what needs interpolation.
      extraConfig = ''
        source ${../config/nu/config.nu}

        # User workflow modules (tracked in git under modules/config/nu/)
        source ${../config/nu/llm.nu}
        source ${../config/nu/decision.nu}
        source ${../config/nu/mataroa.nu}
        source ${../config/nu/utils.nu}
        source ${../config/nu/finance.nu}
        source ${../config/nu/de.nu}
        source ${../config/nu/jobby.nu}
        source ${../config/nu/todoist.nu}

        # System & extraction modules
        source ${pkgs.nu_scripts}/share/nu_scripts/modules/data_extraction/ultimate_extractor.nu
        use ${pkgs.nu_scripts}/share/nu_scripts/modules/nix/nufetch.nu

        # High-value custom completions (Carapace handles git, gh, ssh, tar, rg, bat, eza, just, man)
        use ${pkgs.nu_scripts}/share/nu_scripts/custom-completions/nix/nix-completions.nu *
      '';

      plugins = with pkgs.nushellPlugins;
        [
          query
          gstat
          formats
          # highlight
          polars
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          # units
          # dbus
          # semver
          # desktop_notifications
        ];
    };

    carapace = {
      enable = true;
      enableNushellIntegration = true;
    };
  };

  # Declarative symlink for nu-run in ~/.local/bin/
  home.file.".local/bin/nu-run".source = "${nu-run}/bin/nu-run";

  # Every tool the .nu modules call that was not already on PATH from another
  # module. Without these the commands parse fine and then die on `command not
  # found`, which is the failure the audit found on frieren.
  home.packages = with pkgs;
    [
      nu_scripts
      # `sk` (skim) is the fuzzy picker in utils.nu (gist/browse/movie/audible/
      # readpdf/qrdecode/numail clean). Several of those call it unconditionally,
      # so without this they die on a host that has no `sk` on PATH.
      skim
      # `mdq` — markdown scraping in `publicapi`, `scrape md`, `browse mdlink`.
      mdq
      # `zbarimg` — QR decoding in `qrdecode`.
      zbar
      # `pdfinfo` — the `readpdf` skim preview (poppler_utils is a renamed alias).
      poppler-utils
      # Declarative nu-run wrapper for agent scripts and subshells
      nu-run
    ]
    ++ lazyWrappers;
}
