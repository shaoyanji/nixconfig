{lib, ...}: with lib; {
  options.programs.niri = {
    enable = mkEnableOption "niri";
    package = mkOption {
      type = types.nullOr types.package;
      default = null;
    };
    settings = mkOption {
      type = types.anything;
      default = {};
    };
  };
}
