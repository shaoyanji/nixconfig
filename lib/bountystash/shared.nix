# lib/bountystash/shared.nix — the capsule's project-slug rule; its copy is the
# corpus's `capsule` block, so nothing authored is left here.
{lib}: {
  # Derived from the English title and used by both locales, so the German page
  # keeps the English slug.
  slug = title:
    lib.toLower (
      builtins.replaceStrings
      [" " "/" "&" "'" "," "." "(" ")" ":" "—"]
      ["-" "-" "and" "" "" "" "" "" "" "-"]
      title
    );
}
