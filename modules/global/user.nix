# Canonical user constants for this flake.
{
  # System account username & paths
  name = "devji";
  home = "/home/devji";
  group = "devji";

  # Personal identity & contact
  realName = "Shao-yan (Matt) Ji";
  shortName = "Matt Ji";
  email = "jisifu@gmail.com";
  githubEmail = "github@mail.shaoyanji.is-a.dev";
  workEmail = "matt@bountystash.com";
  # Cal.ai scheduling assistant. It reads the Cal.com calendar over email, so an
  # agent that cannot reach the calendar itself asks this address instead of
  # guessing availability (calendar skill, "When the calendar is out of reach").
  calEmail = "mattji@my.cal.ai";

  # The desktop role is a feature list (modules/roles/home.nix). This is the
  # full set: what every host already evaluated before the split, so a host that
  # sets nothing keeps its closure. A headless or lean host sets
  # `fleet.hmUserFeatures` to a subset (nixos) and drops the module, not just its
  # config — which is the point, since option surface is what a gate pays for.
  hmFeatures = [
    "systemd-policy"
    "shell"
    "dev"
    "ai"
    "browser"
    "media"
    "desktop"
  ];
  # The envs.net pubnix account: mail lives on mail.envs.net, not on the host,
  # and the IMAP/SMTP login is the full address rather than the unix name.
  envsEmail = "jisifu@envs.net";
  # Alwaysdata hosting mailbox for Dragon Court.
  alwaysdataEmail = "dragoncourt@alwaysdata.net";
}
