# $HOME is not a git repository, by construction.
#
# A coding agent started in ~ sometimes runs `git init` there. That makes
# starship's git_status walk the whole home tree on every prompt — seconds per
# prompt on a home with .cache/.local/npm trees — and it is why an ssh login
# felt broken after such a session. Starship 1.x has no per-directory module
# switch, so the cheap fix is at the source: ~/.git is a symlink into /proc,
# where nothing can be created. `git status` in ~ then answers "not a git
# repository" in milliseconds, and `git init` in ~ fails instead of silently
# arming the trap.
#
# Repositories *below* home (~/Documents/nixconfig) are untouched: git finds
# their own .git before it ever walks up to ~.
{lib, ...}: let
  sentinel = "/proc/nixconfig-home-is-not-a-git-repository";
in {
  # Before writeBoundary would collide with an existing ~/.git, and after it so
  # `run`/`warnEcho` exist. A real repository in ~ is never deleted here: that
  # would destroy commits, so it is reported and left for the operator.
  home.activation.homeIsNotAGitRepo = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ -L "$HOME/.git" ]; then
      current="$(readlink "$HOME/.git" || true)"
      if [ "$current" != "${sentinel}" ]; then
        run ln -sfn "${sentinel}" "$HOME/.git"
      fi
    elif [ -e "$HOME/.git" ]; then
      warnEcho "$HOME/.git is a real git repository; leaving it alone."
      warnEcho "It makes every prompt in ~ cost a full home-tree git status."
      warnEcho "If it holds nothing you need:  rm -rf ~/.git"
    else
      run ln -sfn "${sentinel}" "$HOME/.git"
    fi
  '';
}
