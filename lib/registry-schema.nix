{
  knobPathRoots = ["modules/profiles/" "modules/services/"];
  knobPathExceptions = {
    ai = "modules/global/noDE.nix";
  };
  optionCasingExceptions = [
    "profiles.dwlDesktop.enable"
    "services.zettelGraph.enable"
    "services.mataroaConsole.enable"
    "services.jobDbScraper.enable"
    "services.privateDeals.enable"
  ];
  umbrellaFamilies = ["checks:appflow"];
  sopsAnchorExceptions = ["garnix"];
}
