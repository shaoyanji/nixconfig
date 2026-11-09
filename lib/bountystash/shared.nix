# lib/bountystash/shared.nix — section vocabulary and project slugs for the Gemini
# capsule (lib/gemini-portal.nix). bountystash.com is the console in its own repo;
# the data here is what the capsule compiles, not a second site.
{lib}: rec {
  labels = {
    en = {
      profile = "Profile";
      metrics = "At a glance";
      work = "Selected work";
      stack = "Stack";
      principles = "Operating principles";
      record = "Record";
      skip = "Skip to content";
      back = "← Selected work";
      impact = "Impact";
      stackLabel = "Stack";
      kind = "Case study";
      items = "entries";
      education = "Education";
      auth = "Work authorisation";
      contact = "Contact";
      navLabel = "Sections";
      footer = "No JavaScript, no webfonts, no tracking.";
    };
    de = {
      profile = "Profil";
      metrics = "Auf einen Blick";
      work = "Ausgewählte Arbeiten";
      stack = "Werkzeuge";
      principles = "Arbeitsprinzipien";
      record = "Werdegang";
      skip = "Zum Inhalt springen";
      back = "← Ausgewählte Arbeiten";
      impact = "Wirkung";
      stackLabel = "Technik";
      kind = "Fallstudie";
      items = "Einträge";
      education = "Ausbildung";
      auth = "Arbeitsberechtigung";
      contact = "Kontakt";
      navLabel = "Abschnitte";
      footer = "Kein JavaScript, keine Webfonts, kein Tracking.";
    };
  };

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
