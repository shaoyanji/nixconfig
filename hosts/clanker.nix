# clanker — the Instabox VM, fleet fixture since 2026-11-06: Ubuntu, account
# `user`, home `/data/home`, own boot/kernel/users, the lean role built for that
# home. Driving it: .agents/skills/instabox/SKILL.md.
{self, ...}: {
  imports = [self.modules."roles.lean"];

  home = {
    username = "user";
    # Measured 2026-11-06: `echo $HOME` is `/data/home`, and activation refuses a
    # generation whose homeDirectory disagrees (`HOME is "/data/home", expected
    # "/home/user"`) — the one thing that cannot be a guess here.
    homeDirectory = "/data/home";
  };

  # Nix on the box is single-user (`/nix`, no daemon) — installed by
  # `task clanker:up` — so a profile-wide install is the only install there is.
  programs.home-manager.enable = true;
}
