# lib/bountystash-mockup.nix — bountystash.com as a bug-bounty and vulnerability
# programme, rendered from lib/bountystash-mockup/data.json (EN) and data.de.json
# (DE at /de/), the same two-locale shape as lib/matt-site.nix.
#
# A concept, not a product: sample data, `noindex`, its own Pages project. It is a
# separate artifact rather than a route on the portfolio so a mockup cannot be
# mistaken for the live site or overwrite it on deploy.
{
  pkgs,
  lib ? pkgs.lib,
  data ? builtins.fromJSON (builtins.readFile ./bountystash-mockup/data.json),
  dataDe ? builtins.fromJSON (builtins.readFile ./bountystash-mockup/data.de.json),
}: let
  esc = lib.escapeXML;
  base = "https://concept.bountystash.com/";

  render = file: values: let
    text = builtins.readFile file;
    names = builtins.attrNames values;
    out = lib.replaceStrings (map (n: "{{${n}}}") names) (map (n: toString values.${n}) names) text;
    unbound = lib.head (lib.splitString "}}" (lib.last (lib.splitString "{{" out)));
  in
    if lib.hasInfix "{{" out
    then throw "template ${toString file}: unbound placeholder {{${unbound}}}"
    else out;

  css = builtins.readFile ./bountystash-mockup/style.css;

  alternates = ''
    <link rel="alternate" hreflang="en" href="${base}">
    <link rel="alternate" hreflang="de" href="${base}de/">
    <link rel="alternate" hreflang="x-default" href="${base}">'';

  langs = ''
    <a href="/" hreflang="en" lang="en">EN</a><span aria-hidden="true">/</span><a href="/de/" hreflang="de" lang="de" aria-current="true">DE</a>'';

  langsEn = ''
    <a href="/" hreflang="en" lang="en" aria-current="true">EN</a><span aria-hidden="true">/</span><a href="/de/" hreflang="de" lang="de">DE</a>'';

  page = {
    d,
    lang,
    cssHref,
    langs,
  }: let
    nav = lib.concatMapStringsSep "" (s: ''<a href="#${s.id}">${esc s.label}</a>'') d.nav;

    stats =
      lib.concatMapStringsSep "" (s: ''
        <div class="stat"><strong>${esc s.value}</strong><span>${esc s.label}</span></div>
      '')
      d.stats;

    rows =
      lib.concatMapStringsSep "" (r: ''
        <tr>
          <td class="cve">${esc r.cve}</td>
          <td>${esc r.product}</td>
          <td><span class="sev ${esc r.severity}">${esc r.severityLabel} <b>${esc r.cvss}</b></span></td>
          <td><span class="ransom${lib.optionalString (!r.ransomware) " no"}">${
          if r.ransomware
          then esc d.ui.yes
          else esc d.ui.no
        }</span></td>
          <td><span class="chip">${esc r.cluster}</span></td>
          <td class="num">${esc r.effort}</td>
        </tr>
      '')
      d.kev.rows;

    columns = lib.concatMapStringsSep "" (c: "<th>${esc c}</th>") d.kev.columns;

    clusters =
      lib.concatMapStringsSep "" (c: ''
        <article class="cluster">
          <p class="cid">${esc d.ui.cluster} ${esc c.id}</p>
          <h3>${esc c.name}</h3>
          <p class="nums"><span>${toString c.cves} ${esc d.ui.cvesUnit}</span><span>${esc c.effort} ${esc d.ui.effortUnit}</span><span>${toString c.exposure}${esc d.ui.exposureUnit}</span></p>
          <span class="bar" style="--w: ${toString c.exposure}%"></span>
          <p>${esc c.action}</p>
        </article>
      '')
      d.clusters;

    steps =
      lib.concatMapStringsSep "" (s: ''
        <li>
          <span class="num">${esc s.n}</span>
          <h3>${esc s.title}</h3>
          <p>${esc s.body}</p>
        </li>
      '')
      d.method;

    tiers =
      lib.concatMapStringsSep "" (t: ''
        <article class="tier${lib.optionalString t.featured " featured"}">
          <h3>${esc t.name}</h3>
          <p class="price">${esc t.price}</p>
          <p>${esc t.body}</p>
        </article>
      '')
      d.tiers;

    body = ''
      <section class="hero">
        <p class="kicker">${esc d.hero.kicker}</p>
        <h1>${esc d.hero.title}</h1>
        <p class="lede">${esc d.hero.body}</p>
        <p class="actions">
          <a class="btn" href="${d.hero.cta.href}">${esc d.hero.cta.label}</a>
          <a class="btn ghost" href="${d.hero.alt.href}">${esc d.hero.alt.label}</a>
        </p>
        <div class="stats">${stats}</div>
      </section>

      <section id="exposure">
        <div class="sechead">
          <h2><span>01</span> ${esc d.kev.title}</h2>
          <p>${esc d.subtitles.exposure}</p>
        </div>
        <div class="tablewrap">
          <table>
            <thead><tr>${columns}</tr></thead>
            <tbody>${rows}</tbody>
          </table>
        </div>
        <p class="note">${esc d.kev.note}</p>
      </section>

      <section id="clusters">
        <div class="sechead">
          <h2><span>02</span> ${esc d.clustersTitle}</h2>
          <p>${esc d.subtitles.clusters}</p>
        </div>
        <div class="clusters">${clusters}</div>
        <p class="note">${esc d.clustersNote}</p>
      </section>

      <section id="method">
        <div class="sechead">
          <h2><span>03</span> ${esc d.methodTitle}</h2>
          <p>${esc d.subtitles.method}</p>
        </div>
        <ol class="method">${steps}</ol>
      </section>

      <section id="program">
        <div class="sechead">
          <h2><span>04</span> ${esc d.programTitle}</h2>
          <p>${esc d.subtitles.program}</p>
        </div>
        <div class="tiers">${tiers}</div>
        <p class="note">${esc d.programNote}</p>
      </section>
    '';
  in
    render ./bountystash-mockup/shell.html {
      inherit body nav langs cssHref;
      htmlLang = lang;
      alternates = alternates;
      canonical =
        if lang == "de"
        then base + "de/"
        else base;
      ogLocale =
        if lang == "de"
        then "de_DE"
        else "en_GB";
      title =
        if lang == "de"
        then "bountystash — Schwachstellenbetrieb (Konzept-Mockup)"
        else "bountystash — vulnerability operations (concept mockup)";
      description =
        if lang == "de"
        then "Ein Konzept für ein Bug-Bounty- und Schwachstellenprogramm: KEV-Einträge von CISA als Aufwands-Cluster, sortiert nach dem Risiko, das sie pro Stunde entfernen. Beispieldaten."
        else "A concept for a bug-bounty and vulnerability programme: CISA KEV entries grouped into effort clusters and ordered by risk removed per hour. Sample data.";
      brandName = d.brand.name;
      badge = esc d.brand.badge;
      banner = esc d.ui.banner;
      topLabel = esc d.ui.top;
      ctaHref = d.hero.alt.href;
      ctaLabel = esc d.hero.alt.label;
      footer = esc d.footer;
    };

  en = page {
    d = data;
    lang = "en";
    cssHref = "style.css";
    langs = langsEn;
  };
  de = page {
    d = dataDe;
    lang = "de";
    cssHref = "../style.css";
    langs = langs;
  };

  cssFile = pkgs.writeText "mockup-style.css" css;
  enFile = pkgs.writeText "mockup-index.html" en;
  deFile = pkgs.writeText "mockup-de.html" de;
in
  pkgs.runCommand "bountystash-mockup" {} ''
    mkdir -p $out/de
    install -m 0644 ${cssFile} $out/style.css
    install -m 0644 ${enFile} $out/index.html
    install -m 0644 ${deFile} $out/de/index.html
    cat > $out/robots.txt <<'EOF'
    User-agent: *
    Disallow: /
    EOF
    cat > $out/404.html <<'EOF'
    <!doctype html><html lang="en"><meta charset="utf-8"><title>Not found</title>
    <body style="font:15px ui-monospace,monospace;padding:4rem;max-width:40rem">
    <h1>404</h1><p>No such page. / Keine solche Seite.</p><p><a href="/">bountystash mockup</a></p>
    EOF
    echo "bountystash-mockup: $(find $out -type f | wc -l) files, $(du -sb $out | cut -f1) bytes, en+de"
  ''
