# $HOME is not a git repository, by construction: ~/.git is a symlink into /proc,
# so `git init` in ~ fails instead of arming starship's whole-tree git_status walk,
# and repositories below home are untouched. Rationale: docs/nix-patterns.md.
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
