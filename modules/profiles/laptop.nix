# Laptop profile: libinput, auto-cpufreq and the power services a portable host needs.
_: {
  services = {
    libinput.enable = true;
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
}
