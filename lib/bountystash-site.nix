# ==============================================================================
# lib/bountystash-site.nix — the portfolio, as evaluated data
# ==============================================================================
# Same principles as lib/aki-site.nix, applied to bountystash.com:
#
#   * data is evaluated, never typed. Every figure, title and sentence on the
#     page is an interpolation of `portfolio*.json`; there is no literal copy
#     that can outlive the data it describes.
#   * markup lives in files (`bountystash/shell.html`, `project.html`) so it is
#     reviewable as HTML, and `render` refuses to emit a page with a hole left.
#   * no JavaScript, no webfonts, no network asset: one CSS file, real anchors,
#     and `details` for the only interaction the page needs.
#   * two locales from two data files: `/` and `/de/`, with the same slug per
#     project so a case study has one canonical URL in both languages.
#
# The data files are copied from the console repo (`bountystash-console/data/`)
# because a flake input pointing at a machine-local path cannot resolve in CI.
# ==============================================================================
{
  pkgs,
  lib ? pkgs.lib,
  data ? builtins.fromJSON (builtins.readFile ./bountystash/portfolio.json),
  dataDe ? builtins.fromJSON (builtins.readFile ./bountystash/portfolio.de.json),
}: let
  esc = lib.escapeXML;

  render = file: values: let
    text = builtins.readFile file;
    names = builtins.attrNames values;
    out = lib.replaceStrings (map (n: "{{${n}}}") names) (map (n: toString values.${n}) names) text;
    unbound = lib.head (lib.splitString "}}" (lib.last (lib.splitString "{{" out)));
  in
    if lib.hasInfix "{{" out
    then throw "template ${toString file}: unbound placeholder {{${unbound}}}"
    else out;

  slug = title:
    lib.toLower (
      builtins.replaceStrings
      [" " "/" "&" "'" "," "." "(" ")" ":" "—"]
      ["-" "-" "and" "" "" "" "" "" "" "-"]
      title
    );

  slugs = map (p: slug p.title) data.projects;
  projectAt = i: {
    en = builtins.elemAt data.projects i;
    de = builtins.elemAt dataDe.projects i;
    url = "${builtins.elemAt slugs i}.html";
  };

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
      footer = "Compiled by Nix from portfolio.json — no JavaScript, no webfonts, no tracking.";
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
      footer = "Von Nix aus portfolio.json erzeugt — kein JavaScript, keine Webfonts, kein Tracking.";
    };
  };

  css = builtins.readFile ./bountystash/style.css;

  mkLocale = lang: let
    d =
      if lang == "de"
      then dataDe
      else data;
    t = labels.${lang};
    root =
      if lang == "de"
      then "../"
      else "";
    p = d.profile;

    nav = lib.concatMapStringsSep "" (s: ''<a href="${root}index.html#${s.id}">${s.n} ${esc s.label}</a>'') [
      {
        id = "profile";
        n = "00";
        label = t.profile;
      }
      {
        id = "metrics";
        n = "01";
        label = t.metrics;
      }
      {
        id = "work";
        n = "02";
        label = t.work;
      }
      {
        id = "stack";
        n = "03";
        label = t.stack;
      }
      {
        id = "principles";
        n = "04";
        label = t.principles;
      }
      {
        id = "record";
        n = "05";
        label = t.record;
      }
    ];

    metrics =
      lib.concatMapStringsSep "" (m: ''
        <div><dt>${esc m.label}</dt><dd>${esc m.value}</dd></div>
      '')
      d.metrics;

    workRows = lib.concatMapStringsSep "" (i: let
      pr = projectAt i;
      x = pr.en;
    in ''
      <li><a href="${root}work/${pr.url}">
        <span class="yr">${esc x.period}</span>
        <span><strong>${esc x.title}</strong><span class="org">${esc x.role}</span></span>
        <span class="go" aria-hidden="true">→</span>
      </a></li>
    '') (lib.range 0 (builtins.length data.projects - 1));

    stack =
      lib.concatMapStringsSep "" (c: ''
        <details>
          <summary><span>${esc c.category}</span><span>${toString (builtins.length c.items)} ${t.items}</span></summary>
          <ul class="tags">${lib.concatMapStringsSep "" (i: "<li>${esc i}</li>") c.items}</ul>
        </details>
      '')
      d.skills;

    principles =
      lib.concatMapStringsSep "" (x: ''
        <article><h3>${esc x.title}</h3><p>${esc x.body}</p></article>
      '')
      d.philosophy;

    education = lib.concatMapStringsSep "" (e: "
      <span>${esc e.degree} — ${esc e.school} <span class=\"org\">${esc e.period}</span></span>
    ") p.education;

    contacts = lib.concatMapStringsSep " · " (c: ''<a href="${c.href}">${esc c.label}</a>'') [
      {
        label = "email";
        href = "mailto:${p.contacts.email}";
      }
      {
        label = "github";
        href = p.contacts.github;
      }
      {
        label = "linkedin";
        href = p.contacts.linkedin;
      }
    ];

    body = ''
      <section id="profile">
        <h2><span>00</span> ${t.profile}</h2>
        <p class="lede">${esc p.bio}</p>
      </section>

      <section id="metrics">
        <h2><span>01</span> ${t.metrics}</h2>
        <dl class="metrics">${metrics}</dl>
      </section>

      <section id="work">
        <h2><span>02</span> ${t.work}</h2>
        <ol class="work">${workRows}</ol>
      </section>

      <section id="stack">
        <h2><span>03</span> ${t.stack}</h2>
        ${stack}
      </section>

      <section id="principles">
        <h2><span>04</span> ${t.principles}</h2>
        <div class="principles">${principles}</div>
      </section>

      <section id="record">
        <h2><span>05</span> ${t.record}</h2>
        <dl class="record">
          <dt>${t.education}</dt><dd class="edu">${education}</dd>
          <dt>${t.auth}</dt><dd>${esc p.work_auth.citizenship} · ${esc p.work_auth.residency} · ${esc p.work_auth.languages}</dd>
          <dt>${t.contact}</dt><dd>${contacts}</dd>
        </dl>
      </section>
    '';

    index = render ./bountystash/shell.html {
      inherit lang nav body contacts;
      title = "${p.name} — ${p.title}";
      description = "${p.title} — ${p.subtitle}";
      cssHref = "${root}style.css";
      locale =
        if lang == "de"
        then "de_DE"
        else "en_US";
      altEn = "${root}index.html";
      altDe = "${root}de/index.html";
      langSwitch =
        if lang == "de"
        then ''<a href="${root}index.html" hreflang="en">EN</a><span aria-hidden="true">/</span><span aria-current="page">DE</span>''
        else ''<span aria-current="page">EN</span><span aria-hidden="true">/</span><a href="${root}de/index.html" hreflang="de">DE</a>'';
      handle = p.handle;
      location = p.location;
      name = p.name;
      role = p.title;
      subtitle = p.subtitle;
      status = p.status.text;
      skip = t.skip;
      navLabel = t.navLabel;
      footer = t.footer;
    };

    projectPage = i: let
      pr = projectAt i;
      x =
        if lang == "de"
        then pr.de
        else pr.en;
      body = render ./bountystash/project.html {
        index = "0${toString (i + 1)}";
        kind = t.kind;
        title = x.title;
        role = x.role;
        period = x.period;
        description = x.description;
        impact = x.impact;
        impactLabel = t.impact;
        stackLabel = t.stackLabel;
        stack = lib.concatMapStringsSep "" (s: "<li>${esc s}</li>") x.stack;
        backHref = "${root}index.html#work";
        backLabel = t.back;
        cssHref = "${root}style.css";
      };
    in
      render ./bountystash/shell.html {
        inherit lang nav body contacts;
        title = "${esc x.title} — ${p.name}";
        description = x.role;
        cssHref = "${root}style.css";
        locale =
          if lang == "de"
          then "de_DE"
          else "en_US";
        altEn = "${root}work/${pr.url}";
        altDe = "${root}de/work/${pr.url}";
        langSwitch =
          if lang == "de"
          then ''<a href="${root}work/${pr.url}" hreflang="en">EN</a><span aria-hidden="true">/</span><span aria-current="page">DE</span>''
          else ''<span aria-current="page">EN</span><span aria-hidden="true">/</span><a href="${root}de/work/${pr.url}" hreflang="de">DE</a>'';
        handle = p.handle;
        location = p.location;
        name = p.name;
        role = p.title;
        subtitle = p.subtitle;
        status = p.status.text;
        skip = t.skip;
        navLabel = t.navLabel;
        footer = t.footer;
      };
  in {
    inherit index projectPage root;
  };

  en = mkLocale "en";
  de = mkLocale "de";

  cssFile = pkgs.writeText "bountystash-style.css" css;
  page = name: html: pkgs.writeText name html;
in
  pkgs.runCommand "bountystash-site" {} ''
    mkdir -p $out/work $out/de/work
    install -m 0644 ${cssFile} $out/style.css
    install -m 0644 ${page "index.html" en.index} $out/index.html
    install -m 0644 ${page "de-index.html" de.index} $out/de/index.html
    ${lib.concatMapStringsSep "\n" (i: let
      pr = projectAt i;
    in ''
      install -m 0644 ${page "en-${pr.url}" (en.projectPage i)} $out/work/${pr.url}
      install -m 0644 ${page "de-${pr.url}" (de.projectPage i)} $out/de/work/${pr.url}
    '') (lib.range 0 (builtins.length data.projects - 1))}
    cat > $out/robots.txt <<'EOF'
    User-agent: *
    Allow: /
    EOF
    cat > $out/404.html <<'EOF'
    <!doctype html><html lang="en"><meta charset="utf-8"><title>Not found</title>
    <body style="font:16px ui-monospace,monospace;padding:4rem;max-width:40rem">
    <h1>404</h1><p>No such page.</p><p><a href="/">bountystash.com</a></p>
    EOF
    echo "site: $(find $out -type f | wc -l) files, $(du -sb $out | cut -f1) bytes"
  ''
