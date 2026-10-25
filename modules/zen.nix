{
  inputs,
  pkgs,
  config,
  lib,
  ...
}: {
  imports = [
    inputs.zen-browser.homeModules.beta
    ./aria2.nix
  ];

  # Zen expects profiles under ~/.zen on Linux, but the flake's Home Manager
  # module populates ~/.config/zen. Mirror the out-of-store symlink pattern
  # from nixoshmsymlinks.nix so all hosts resolve profiles consistently.
  home.file = lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && config.programs.zen-browser.enable) {
    ".zen".source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/zen";
  };

  programs = {
    zen-browser = {
      enable = true;
      policies = {
        # Firefox-family browsers keep their own NSS trust store and ignore
        # the system one; this makes zen trust the frieren LAN CA so
        # https://*.frieren.lan works without per-profile overrides.
        Certificates.Install = ["${./config/tls/frieren-lan-ca.pem}"];
        AutofillAddressEnabled = true;
        AutofillCreditCardEnabled = false;
        DisableAppUpdate = true;
        DisableFeedbackCommands = true;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisableTelemetry = true;
        DontCheckDefaultBrowser = true;
        NoDefaultBookmarks = true;
        OfferToSaveLogins = false;
        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
        };
        SearchEngines = {
          Default = "SearXNG";
          PreventInstalls = false;
          Add = [
            {
              Name = "SearXNG";
              URLTemplate = "https://delphi.cloudforest-kardashev.ts.net:8447/search?q={searchTerms}";
              Method = "GET";
              IconURL = "https://delphi.cloudforest-kardashev.ts.net:8447/favicon.ico";
              Alias = "@s";
              Description = "Delphi SearXNG Meta-Search";
              SuggestURLTemplate = "https://delphi.cloudforest-kardashev.ts.net:8447/autocompleter?q={searchTerms}";
            }
          ];
        };
      };
      profiles."m4i7gl4m.default" = {
        search = {
          force = true;
          default = "SearXNG";
          order = ["SearXNG" "Google"];
          engines = {
            "SearXNG" = {
              urls = [
                {
                  template = "https://delphi.cloudforest-kardashev.ts.net:8447/search";
                  params = [
                    {
                      name = "q";
                      value = "{searchTerms}";
                    }
                  ];
                }
                {
                  type = "application/x-suggestions+json";
                  template = "https://delphi.cloudforest-kardashev.ts.net:8447/autocompleter";
                  params = [
                    {
                      name = "q";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              iconUpdateURL = "https://delphi.cloudforest-kardashev.ts.net:8447/favicon.ico";
              updateInterval = 24 * 60 * 60 * 1000;
              definedAliases = ["@s" "@searxng"];
            };
          };
        };
        settings = {
          "widget.use-xdg-desktop-portal.file-picker" = 1;
          "security.enterprise_roots.enabled" = true;
          # Without these, profile-scope XPIs arrive userDisabled=true.
          "extensions.autoDisableScopes" = 0;
          "extensions.enabledScopes" = 15;
        };
        extensions.packages = with inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}; [
          ublock-origin
          raindropio
          bitwarden
          privacy-badger
          darkreader
          vimium
          web-clipper-obsidian
          a11ycss
          catppuccin-mocha-mauve
          catppuccin-web-file-icons
          consent-o-matic
          copy-as-markdown
          unpaywall
          sponsorblock
          offline-qr-code-generator
          hacktools
          # ghosttext
          geminize
          export-tabs-urls-and-titles
          chatgptbox
          brotab
          aria2-integration
          # single-file
          # wappalyzer
          # ipfs-companion
        ];
        # containersForce = true;
        # containers = {
        #   Personal = {
        #     color = "purple";
        #     icon = "fingerprint";
        #     id = 1;
        #   };
        #   Work = {
        #     color = "blue";
        #     icon = "briefcase";
        #     id = 2;
        #   };
        #   Shopping = {
        #     color = "yellow";
        #     icon = "dollar";
        #     id = 3;
        #   };
        # };
        # spacesForce = true;
        # spaces = let
        #   containers = config.programs.zen-browser.profiles."default".containers;
        # in {
        #   "Space" = {
        #     id = "c6de089c-410d-4206-961d-ab11f988d40a";
        #     position = 1000;
        #   };
        #   "Work" = {
        #     id = "cdd10fab-4fc5-494b-9041-325e5759195b";
        #     icon = "chrome://browser/skin/zen-icons/selectable/star-2.svg";
        #     container = containers."Work".id;
        #     position = 2000;
        #   };
        #   "Shopping" = {
        #     id = "78aabdad-8aae-4fe0-8ff0-2a0c6c4ccc24";
        #     icon = "💸";
        #     container = containers."Shopping".id;
        #     position = 3000;
        #   };
        # };
        #
      };
    };
  };
}
