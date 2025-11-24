{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.zen-browser.homeModules.beta
  ];
  programs = {
    zen-browser = {
      enable = true;
      policies = {
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
      };
      profiles."m4i7gl4m.default" = {
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
          ipfs-companion
          hacktools
          # ghosttext
          geminize
          export-tabs-urls-and-titles
          chatgptbox
          brotab
          aria2-integration
          # single-file

          # wappalyzer
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
    aria2 = {
      enable = true;
      settings = {
        disk-cache = ''32M'';
        file-allocation = ''falloc'';
        continue = true;
        max-concurrent-downloads = 10;
        max-connection-per-server = 16;
        min-split-size = ''10M'';
        split = 5;
        disable-ipv6 = true;
        save-session-interval = 60;
        #rpc-secret=;
        rpc-listen-port = 6800;
        rpc-allow-origin-all = true;
        rpc-listen-all = true;
        follow-torrent = true;
        listen-port = 51413;
        bt-max-peers = 100;
        enable-dht = true;
        enable-dht6 = true;
        dht-listen-port = 6966;
        enable-peer-exchange = true;
        peer-id-prefix = "-TR2770-";
        peer-agent = ''Transmission/2.77'';
        user-agent = ''Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:56.0) Gecko/20100101 Firefox/56.0'';
        seed-ratio = 0;
        bt-hash-check-seed = true;
        bt-seed-unverified = true;
        bt-save-metadata = false;
        enable-rpc = true;
        max-upload-limit = "50K";
        ftp-pasv = true;
      };
    };
  }; # nixpkgs.config.allowUnfree = true;
}
