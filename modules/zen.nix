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
          geminize
          export-tabs-urls-and-titles
          chatgptbox
          brotab
          aria2-integration
          # Power tool & privacy additions
          ghosttext
          single-file
          refined-github
          clearurls
          fastforwardteam
          open-in-freedium
          web-archives
          return-youtube-dislikes
          dearrow
          page-assist
          translate-web-pages
          # Note: wappalyzer is unfree ('allrightsreserved'); excluded from pure flake build
          # ipfs-companion
        ];
        spacesForce = false;
        spaces = {
          "Delphi Cloud" = {
            id = "c6de089c-410d-4206-961d-ab11f988d40a";
            position = 1000;
            icon = "☁️";
            pins = {
              "SearXNG" = {
                id = "d1a10001-0000-4000-8000-000000000001";
                url = "https://delphi.cloudforest-kardashev.ts.net:8447";
                position = 1000;
              };
              "Stirling PDF" = {
                id = "d1a10001-0000-4000-8000-000000000002";
                url = "https://delphi.cloudforest-kardashev.ts.net:8445";
                position = 2000;
              };
              "Uptime Kuma" = {
                id = "d1a10001-0000-4000-8000-000000000003";
                url = "https://delphi.cloudforest-kardashev.ts.net:8448";
                position = 3000;
              };
              "Service Portal" = {
                id = "d1a10001-0000-4000-8000-000000000004";
                url = "https://delphi.cloudforest-kardashev.ts.net:8446";
                position = 4000;
              };
              "DeepSeek Harness" = {
                id = "d1a10001-0000-4000-8000-000000000005";
                url = "https://delphi.cloudforest-kardashev.ts.net:8443";
                position = 5000;
              };
            };
          };
          "Frieren Mainframe" = {
            id = "cdd10fab-4fc5-494b-9041-325e5759195b";
            position = 2000;
            icon = "🏰";
            pins = {
              "Immich Photos" = {
                id = "f1a10002-0000-4000-8000-000000000001";
                url = "https://photos.frieren.lan";
                position = 1000;
              };
              "Jellyfin Media" = {
                id = "f1a10002-0000-4000-8000-000000000002";
                url = "https://media.frieren.lan";
                position = 2000;
              };
              "Audiobookshelf" = {
                id = "f1a10002-0000-4000-8000-000000000003";
                url = "https://audiobooks.frieren.lan";
                position = 3000;
              };
              "Vaultwarden" = {
                id = "f1a10002-0000-4000-8000-000000000004";
                url = "https://vault.frieren.lan";
                position = 4000;
              };
              "Home Assistant" = {
                id = "f1a10002-0000-4000-8000-000000000005";
                url = "https://ha.frieren.lan";
                position = 5000;
              };
              "Transmission Torrent" = {
                id = "f1a10002-0000-4000-8000-000000000006";
                url = "https://torrent.frieren.lan";
                position = 6000;
              };
              "Kiwix Offline Wiki" = {
                id = "f1a10002-0000-4000-8000-000000000007";
                url = "https://wiki.frieren.lan";
                position = 7000;
              };
              "Fleet Docs" = {
                id = "f1a10002-0000-4000-8000-000000000008";
                url = "https://docs.frieren.lan";
                position = 8000;
              };
              "Paste (pb)" = {
                id = "f1a10002-0000-4000-8000-000000000009";
                url = "https://paste.frieren.lan";
                position = 9000;
              };
            };
          };
        };
      };
    };
  };
}
