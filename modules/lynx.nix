# Lynx: cookie-free by default, vi keys, and the fleet's own editor.
{
  config,
  pkgs,
  ...
}: let
  user = import ./global/user.nix;

  # The one editor source in the tree is `home.sessionVariables.EDITOR`.
  editor = config.home.sessionVariables.EDITOR or "hx";

  # `NAME=VALUE`, not lynx.cfg's `NAME:VALUE`: read_rc splits on '=' and drops
  # any line without one. Only ENABLE_LYNXRC-listed options are honoured here.
  rc = ''
    ACCEPT_ALL_COOKIES=FALSE
    COOKIE_ACCEPT_DOMAINS=
    COOKIE_REJECT_DOMAINS=
    FILE_EDITOR=${editor}
    PREFERRED_LANGUAGE=en,de
    CHARACTER_SET=utf-8
    PREFERRED_CHARSET=utf-8
    VI_KEYS=TRUE
    COLLAPSE_BR_TAGS=FALSE
    SHOW_CURSOR=FALSE
    BOOKMARK_FILE=${user.home}/lynx_bookmarks.html
  '';

  # Refusing cookies is not rc-settable, so it lives in the cfg. LYNX_CFG
  # replaces the packaged lynx.cfg wholesale, so this appends rather than
  # shadowing its colours, help URL and session defaults.
  lynxCfg = pkgs.runCommand "lynx.cfg" {} ''
    cat ${pkgs.lynx}/etc/lynx.cfg > $out
    cat >> $out <<'CFG'

    SET_COOKIES:FALSE
    PERSISTENT_COOKIES:FALSE
    ENABLE_LYNXRC:COLLAPSE_BR_TAGS:ON
    CFG
  '';
in {
  home.packages = [pkgs.lynx];

  home.file.".lynxrc".text = rc;

  home.sessionVariables.LYNX_CFG = "${lynxCfg}";
}
