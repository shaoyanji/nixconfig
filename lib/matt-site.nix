# lib/matt-site.nix — matt.bountystash.com, two locales over one shell.
#
# A sibling of lib/bountystash-site.nix and no second renderer: the same shape
# (JSON in, shell.html plus style.css out, one CSS file), so a change to the
# vocabulary of one page cannot drift into a different mechanism on the other.
# Colour is one `light-dark()` pair per token and one `color-scheme` switch, so
# the toggle cannot introduce a palette the stylesheet does not already own.
{
  pkgs,
  lib ? pkgs.lib,
  data ? builtins.fromJSON (builtins.readFile ./matt/profile.json),
  dataDe ? builtins.fromJSON (builtins.readFile ./matt/profile.de.json),
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

  css = builtins.readFile ./matt/style.css;

  sections = [
    {
      id = "focus";
      n = "00";
    }
    {
      id = "work";
      n = "01";
    }
    {
      id = "lab";
      n = "02";
    }
    {
      id = "stack";
      n = "03";
    }
    {
      id = "hire";
      n = "04";
    }
  ];

  mkLocale = lang: let
    d =
      if lang == "de"
      then dataDe
      else data;
    p = d.profile;
    ui = d.ui;
    root =
      if lang == "de"
      then "../"
      else "";
    pageUrl =
      if lang == "de"
      then "${p.url}/de/"
      else "${p.url}/";

    nav = lib.concatMapStringsSep "" (s: ''<a href="#${s.id}">${s.n} ${esc ui.nav.${s.id}}</a>'') sections;

    contacts = lib.concatMapStringsSep "" (c: ''<a href="${c.href}">${esc c.label}</a>'') p.contacts;

    focusCards =
      lib.concatMapStringsSep "" (f: ''
        <article class="card">
          <h3>${esc f.title}</h3>
          <p>${esc f.body}</p>
        </article>
      '')
      d.focus;

    workRows =
      lib.concatMapStringsSep "" (w: ''
        <li>
          <span class="yr">${esc w.period}</span>
          <div>
            <strong>${
          if w.link == ""
          then esc w.title
          else ''<a href="${w.link}">${esc w.title}</a>''
        }</strong>
            <span class="org">${esc w.role}</span>
            <p>${esc w.description}</p>
          </div>
        </li>
      '')
      d.work;

    labLinks =
      lib.concatMapStringsSep " · " (l: ''<a href="${l.href}">${esc l.label}</a>'') d.lab.links;

    stackGroups =
      lib.concatMapStringsSep "" (g: ''
        <details>
          <summary><span>${esc g.category}</span><span>${toString (builtins.length g.items)}</span></summary>
          <ul class="tags">${lib.concatMapStringsSep "" (i: "<li>${esc i}</li>") g.items}</ul>
        </details>
      '')
      d.stack;

    wants = lib.concatMapStringsSep "" (w: "<li>${esc w}</li>") d.hire.wants;

    # Contact links are looked up by label rather than by position, so reordering
    # profile.json cannot point the structured data at the wrong site.
    contactHref = label: (builtins.head (builtins.filter (c: c.label == label) p.contacts)).href;

    jsonld =
      builtins.replaceStrings ["<"] ["\\u003c"]
      (builtins.toJSON {
        "@context" = "https://schema.org";
        "@type" = "Person";
        name = p.name;
        jobTitle = p.title;
        description = p.bio;
        url = pageUrl;
        email = contactHref "email";
        inLanguage = lang;
        sameAs = [
          (contactHref "github")
          (contactHref "linkedin")
        ];
        address = {
          "@type" = "PostalAddress";
          addressLocality = "Gutach im Breisgau";
          addressCountry = "DE";
        };
      });

    body = ''
      <section id="focus">
        <h2><span>00</span> ${esc ui.headings.focus}</h2>
        <div class="cards">${focusCards}</div>
      </section>

      <section id="work">
        <h2><span>01</span> ${esc ui.headings.work}</h2>
        <ol class="work">${workRows}</ol>
      </section>

      <section id="lab">
        <h2><span>02</span> ${esc d.lab.title}</h2>
        <div class="lab">
          <p>${esc d.lab.body}</p>
          <p class="tools">${labLinks}</p>
        </div>
      </section>

      <section id="stack">
        <h2><span>03</span> ${esc ui.headings.stack}</h2>
        ${stackGroups}
      </section>

      <section id="hire">
        <h2><span>04</span> ${esc d.hire.title}</h2>
        <div class="hire">
          <p>${esc d.hire.body}</p>
          <ul>${wants}</ul>
          <a class="cta" href="${d.hire.cta.href}">${esc d.hire.cta.label}</a>
        </div>
      </section>
    '';

    langSwitch =
      if lang == "de"
      then ''<a href="${root}index.html" hreflang="en" lang="en">EN</a><span class="sep" aria-hidden="true">/</span><span aria-current="page">DE</span>''
      else ''<span aria-current="page">EN</span><span class="sep" aria-hidden="true">/</span><a href="${root}de/index.html" hreflang="de" lang="de">DE</a>'';
  in
    render ./matt/shell.html {
      inherit lang nav contacts jsonld body langSwitch;
      title = "${p.name} — ${p.title}";
      description = "${p.title}. ${p.subtitle}.";
      url = pageUrl;
      altEn = "${p.url}/";
      altDe = "${p.url}/de/";
      locale =
        if lang == "de"
        then "de_DE"
        else "en_US";
      inherit (p) handle;
      inherit (p) status;
      inherit (p) location;
      inherit (p) name;
      role = p.title;
      inherit (p) subtitle;
      inherit (p) bio;
      inherit (ui) skip;
      inherit (ui) navLabel;
      inherit (ui) theme;
      inherit (ui) themeAria;
      inherit (ui) langLabel;
      inherit (ui) footer;
      cssHref = "${root}style.css";
    };

  en = mkLocale "en";
  de = mkLocale "de";

  page = name: content: pkgs.writeText name content;
  cssFile = pkgs.writeText "matt-style.css" css;
in
  pkgs.runCommand "matt-site" {} ''
    mkdir -p $out/de
    install -m 0644 ${cssFile} $out/style.css
    install -m 0644 ${page "index.html" en} $out/index.html
    install -m 0644 ${page "de-index.html" de} $out/de/index.html
    cat > $out/robots.txt <<'EOF'
    User-agent: *
    Allow: /
    EOF
    cat > $out/404.html <<'EOF'
    <!doctype html><html lang="en"><meta charset="utf-8"><title>Not found</title>
    <body style="font:16px ui-monospace,monospace;padding:4rem;max-width:40rem">
    <h1>404</h1><p>No such page.</p><p><a href="/">matt.bountystash.com</a></p>
    EOF
    echo "matt-site: $(find $out -type f | wc -l) files, $(du -sb $out | cut -f1) bytes"
  ''
