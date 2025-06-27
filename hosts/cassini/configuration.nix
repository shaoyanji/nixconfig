{
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
  ];

  homebrew = {
    enable = true;
    taps = [
      #"gigalixir/brew"
      #"krtirtho/apps"
      #"homebrew/cask-fonts"
      #"dart-lang/dart"
      #"homebrew/bundle"
      #"homebrew/services"
    ];
    brews = [
      # "mas"
      # "gigalixir"
      "tesseract"
      "imagemagick"
      "ghostscript"
      "xpdf"
      "gemini-cli"
    ];
    casks = [
      "ghostty"
      "orbstack"
      "obsidian"
      "zen"
      "raycast"
      "keybase"
      "notion"
      "slack"
      "zoom"
      "freetube"
      "steam"
      "unnaturalscrollwheels"
      "container"
      "logitech-g-hub"
      "wezterm@nightly"
      "libreoffice"
      "microsoft-excel"
      "microsoft-teams"
      "rustdesk"
      "google-drive"
      "dropbox"
      "onedrive"
      "box-drive"
      "warp"
      "ollama-app"
      # "kitty"
      #"arc"
      # "logitech-camera-settings"
      # "wine-stable"#d
      # "zed"#d
      # "obs"#d
      # "sabaki" #d
      # "colmap"
      # "lagrange"
    ];
    masApps = {
      # Xcode = 497799835;
      # "ISH" = 1436902243;
      # "Steamlink" = 1246969117;
    };
    onActivation.cleanup = "zap";
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
  };
  # Nix configuration ------------------------------------------------------------------------------
  # Deprecation notice Feb 20, 2025
  # nix.configureBuildUsers = true;

  # Enable experimental nix command and flakes
  # nix.package = pkgs.nixUnstable;
  nix.extraOptions =
    ''
      auto-optimise-store = true
      experimental-features = nix-command flakes
    ''
    + lib.optionalString (pkgs.system == "aarch64-darwin") ''
      extra-platforms = x86_64-darwin aarch64-darwin
    '';

  # Create /etc/bashrc that loads the nix-darwin environment.
  programs.zsh.enable = true;
  # Auto upgrade nix package and the daemon service.
  # services.nix-daemon.enable = true;
  # ^ Deprecation Notice Feb 20, 2025
  # Apps
  # `home-manager` currently has issues adding them to `~/Applications`
  # Issue: https://github.com/nix-community/home-manager/issues/1341
  environment.systemPackages = with pkgs; [
    kitty
    terminal-notifier
    mkalias
  ];

  # https://github.com/nix-community/home-manager/issues/423
  environment.variables = {
    #    TERMINFO_DIRS = "${pkgs.kitty.terminfo.outPath}/share/terminfo";
  };
  programs.nix-index.enable = true;

  # Fonts
  fonts.packages = [
    #(pkgs.nerdfonts.override { fonts = ["JetBrainsMono"]; })
  ];
  system.primaryUser = "devji";
  system.defaults = {
    dock.autohide = true;
    finder.FXPreferredViewStyle = "clmv";
    finder.FXEnableExtensionChangeWarning = false;
    loginwindow.GuestEnabled = false;
    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
    };
    NSGlobalDomain = {
      AppleICUForce24HourTime = true;
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;
      AppleKeyboardUIMode = 3;
      ApplePressAndHoldEnabled = false;
      "com.apple.swipescrolldirection" = true;
      "com.apple.sound.beep.feedback" = 0;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      NSWindowResizeTime = 0.001;
    };
    CustomSystemPreferences."com.apple.Accessibility".ReduceMotionEnabled = 1;
    universalaccess.reduceMotion = true;
    CustomUserPreferences = {
      NSGlobalDomain.WebKitDeveloperExtras = true;
      AppleLanguages = lib.mkForce (lib.mkDefault ["en-US"]);
      ".GlobalPreferences" = {
        AppleSpacesSwitchOnActivate = true;
      };
      "com.apple.finder" = {
        AppleShowAllFiles = true;
        AppleShowAllExtensions = true;
        AppleShowAllFolders = true;
        AppleShowAllLibraries = true;
        AppleShowAllMountedVolumes = true;
        AppleShowAllPackages = true;
        AppleShowAllUsers = true;
        "ShowPathbar" = true;
        "SidebarIconSize" = 16;
        "SortColumn" = "kMDItemFSCreationDate";
        "SortDirection" = 0;
        "ShowStatusBar" = true;
        "ShowTabView" = true;
        "ShowToolbar" = true;
        "ShowSidebar" = true;
        "NewWindowTarget" = "PfHm";
        "NewWindowTargetPath" = "/Users/devji";
        "NewWindowTargetPathIsVolume" = false;
        "FXPreferredViewStyle" = "clmv";
        ShowExternalHardDrivesOnDesktop = true;
        ShowRemovableMediaOnDesktop = true;
        ShowMountedServersOnDesktop = true;
        ShowHardDrivesOnDesktop = true;
        _FXSortFoldersFirst = true;
        FXDefaultSearchScope = "SCcf";
      };
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
      "com.apple.spaces" = {
        "spans-displays" = 0;
      };
      "com.apple.WindowManager" = {
        EnableStandardWindowMenu = 0;
        StandardHideDesktopIcons = 0;
        HideDesktop = 0;
        StandardManagerHideWidgets = 0;
        StandardHideWidgets = 0;
      };
      "com.apple.ImageCapture" = {
        disableHotPlug = true;
      };
      "com.apple.AdLib" = {
        allowApplePersonalizedAdvertising = false;
      };
    };
  };
  # Keyboard
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToEscape = true;

  # Add ability to used TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = true;
  #  security.pam.enableSudoTouchIdAuth = true;

  system.activationScripts.applications.text = let
    env = pkgs.buildEnv {
      name = "system-applications";
      paths = config.environment.systemPackages;
      pathsToLink = "/Applications";
    };
  in
    pkgs.lib.mkForce
    /*
    sh
    */
    ''
      # Set up applications.
      echo "setting up /Applications..." >&2
      rm -rf /Applications/Nix\ Apps
      mkdir -p /Applications/Nix\ Apps
      find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
      while read -r src; do
      app_name=$(basename "$src")
      echo "copying $src" >&2
      ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
      done
    '';
  # Set Git commit hash for darwin-version.
  system.stateVersion = 5;
  system.activationScripts.postActivation.text = ''
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';
  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
}
