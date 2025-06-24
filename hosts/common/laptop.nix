{
  # services.thermald.enable = true;
  #services.tlp = {
  #  enable = true;
  #  settings = {
  #    CPU_SCALING_GOVERNOR_ON_AC = "performance";
  #    CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

  #     CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
  #     CPU_ENERGY_PERF_POLICY_ON_AC = "performance";

  #      CPU_MIN_PERF_ON_AC = 0;
  #      CPU_MAX_PERF_ON_AC = 100;
  #      CPU_MIN_PERF_ON_BAT = 0;
  #      CPU_MAX_PERF_ON_BAT = 20;
  #
  #      #Optional helps save long term battery health
  #      START_CHARGE_THRESH_BAT0 = 40; # 40 and below it starts to charge
  #      STOP_CHARGE_THRESH_BAT0 = 80; # 80 and above it stops charging
  #    };
  #  };
  services = {
    libinput.enable = true; #touchpad support
    auto-cpufreq = {
      enable = true;
      settings = {
        battery = {
          governor = "powersave";
          turbo = "never";
        };
        charger = {
          governor = "performance";
          turbo = "auto";
        };
      };
    };
  };

  # wayland.windowManager.hyprland.settings = {
  #   input = {
  #     # kb_layout = "us";
  #     # kb_variant = ",us";
  #     # follow_mouse = 1;
  #     # sensitivity = 0;
  #     touchpad = {
  #       natural_scroll = true;
  #       disable_while_typing = true;
  #     };
  #   };
  # };
}
