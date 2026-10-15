# Canonical user constants for this flake.
# Import with: let user = import ../global/user.nix; in (or relative path)
# These values are the single source of truth for the primary user.
{
  # System account username & paths
  name = "devji";
  home = "/home/devji";
  group = "devji";

  # Personal identity & contact
  realName = "Shao-yan (Matt) Ji";
  shortName = "Matt Ji";
  email = "jisifu@gmail.com";
  githubEmail = "github@mail.shaoyanji@is-a.dev";
  workEmail = "matt@bountystash.com";
}
