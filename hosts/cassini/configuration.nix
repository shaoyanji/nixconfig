{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: {
  imports = [
  ];

  homebrew = {
    enable = true;
    taps = [
      "cablehead/tap"
    ];
    brews = [
      "tesseract"
      "imagemagick"
      "ghostscript"
      "xpdf"
      "bitwarden-cli"
      "python"
      "uv"
      "yt-dlp"
      "html2markdown"
      "cablehead/tap/cross-stream"
      "svgo"
    ];
    casks = [
      "filo"
      "white-rabbit"
      "anki"
      "helium-browser"
      "simplex"
      "ghostty"
      "orbstack"
      "obsidian"
      "zen"
      "raycast"
      "keybase"
      "notion"
      "slack"
      "zoom"
      "steam"
      "unnaturalscrollwheels"
      "container"
      "logitech-g-hub"
      "wezterm@nightly"
      "google-drive"
      "dropbox"
      "onedrive"
      "box-drive"
      "warp"
      "itsycal"
      "ollama-app"
      "kitty"
      "lagrange"
    ];
    masApps = {};
    onActivation.cleanup = "zap";
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
  };

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    mkalias
  ];

  environment.variables = {};
  programs.nix-index.enable = true;

  fonts.packages = [];
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
    # universalaccess.reduceMotion = true;
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

  # Set Git commit hash for darwin-version.
  system.stateVersion = 5;
  system.activationScripts.postActivation.text = ''
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';
  nixpkgs.hostPlatform = "aarch64-darwin";
}
