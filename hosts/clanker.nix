# clanker — the Instabox VM, permanent fleet fixture since 2026-11-06. Instabox
# boots Ubuntu with the account `user`, so the lean role is built for that home;
# the box's own distro keeps owning boot, kernel and users. How it is driven:
# .agents/skills/instabox/SKILL.md.
{
  imports = [../modules/roles/lean.nix];

  home = {
    username = "user";
    homeDirectory = "/home/user";
  };

  # Nix on the box is single-user (`/nix`, no daemon) — installed by
  # `task clanker:up` — so a profile-wide install is the only install there is.
  programs.home-manager.enable = true;
}
