{
  username = "devji";
  gitUser = "Shao-yan (Matt) Ji";
  gitEmail = "100967396+shaoyanji@users.noreply.github.com";
  host = "poseidon";
  /*
  default password is required for sudo support in systems
  !remember to use passwd to change the password!
  */
  timezone = "Europe/Berlin";
  locale = "en_US.UTF-8";

  # hardware config - sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
  hardwareConfig = toString ../poseidon/hardware-configuration.nix;

  # list of drivers to install in ./hosts/nixos/drivers.nix
  drivers = [
    #"amdgpu"
    #"intel"
    "nvidia"
    "amdcpu"
    # "intel-old"
  ];

  /*
  these will be imported after the default modules and override/merge any conflicting options
  !its very possible to break hydenix by overriding options
  eg:
    # lets say hydenix has a default of:
    {
      services.openssh.enable = true;
      environment.systempackages = [ pkgs.vim ];
    }
    # your module
    {
      services.openssh.enable = false;  #? this wins by default (last definition)
      environment.systempackages = [ pkgs.git ];  #? this gets merged with hydenix
    }
  */
  # list of nix modules to import in ./hosts/nixos/default.nix
  nixModules = [
    (toString ../poseidon/configuration.nix)

    # in my-module.nix you can reference this userconfig
    ({
      userconfig,
      pkgs,
      ...
    }: {
      environment.systemPackages = with pkgs; [
        direnv
        carapace
        cifs-utils
        nfs-utils
      ];
    })
  ];
  # list of nix modules to import in ./lib/mkconfig.nix
  homeModules = [
    (toString ../../modules/global/minimal.nix)
    (toString ../../modules/nixoshmsymlinks.nix)
    (toString ../../modules/nixvim)
  ];

  hyde = rec {
    sddmTheme = "candy"; # or "corners"

    enable = true;

    # wallbash config, sets extensions as active
    wallbash = {
      vscode = true;
    };

    # active theme, must be in themes list
    activeTheme = "Catppuccin Mocha";

    # list of themes to choose from
    themes = [
      # -- Default themes
      # "Catppuccin Latte"
      "Catppuccin Mocha"
      # "Decay Green"
      # "Edge Runner"
      # "Frosted Glass"
      # "Graphite Mono"
      # "Gruvbox Retro"
      # "Material Sakura"
      # "Nordic Blue"
      # "Rose Pine"
      # "Synth Wave"
      # "Tokyo Night"

      # -- Themes from hyde-gallery
      # "Abyssal-Wave"
      # "AbyssGreen"
      # "Bad Blood"
      # "Cat Latte"
      # "Crimson Blade"
      # "Dracula"
      # "Edge Runner"
      # "Green Lush"
      # "Greenify"
      "Hack the Box"
      # "Ice Age"
      "Mac OS"
      # "Monokai"
      # "Monterey Frost"
      # "One Dark"
      # "Oxo Carbon"
      # "Paranoid Sweet"
      # "Pixel Dream"
      # "Rain Dark"
      # "Red Stone"
      "Rose Pine"
      # "Scarlet Night"
      # "Sci-fi"
      # "Solarized Dark"
      "Tokyo Night"
      # "Vanta Black"
      "Windows 11"
    ];

    # exactly the same as hyde.conf
    conf = {
      hydeTheme = activeTheme;
      wallFramerate = 144;
      wallTransDuration = 0.4;
      wallAddCustomPath = "";
      enableWallDcol = 2;
      wallbashCustomCurve = "";
      skip_wallbash = [];
      themeSelect = 2;
      rofiStyle = 11;
      rofiScale = 9;
      wlogoutStyle = 1;
    };
  };

  vm = {
    # 4 gb minimum
    memorySize = 4096;
    # 2 cores minimum
    cores = 2;
    # 30gb minimum for one theme - 50gb for multiple themes - more for development and testing
    diskSize = 20000;
  };
  home-manager.backupFileExtension = "hyde";
  programs.nixvim = {
    enable = true;
    colorschemes.catpuccin.enable = true;
    plugins.lualine.enable = true;
  };
  defaultPassword = "asdf";
}
