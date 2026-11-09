# lib/bountystash-mockup.nix — bountystash.com as a bug-bounty programme from
# data.json (EN) and data.de.json (/de/). Sample data only: `noindex`, its own
# Pages project, so it can neither be mistaken for the live site nor overwrite it.
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
    title =
      if lang == "de"
      then "bountystash — Schwachstellenbetrieb (Konzept-Mockup)"
      else "bountystash — vulnerability operations (concept mockup)";

    description =
      if lang == "de"
      then "Ein Konzept für ein Bug-Bounty- und Schwachstellenprogramm: KEV-Einträge von CISA als Aufwands-Cluster, sortiert nach dem Risiko, das sie pro Stunde entfernen. Beispieldaten."
      else "A concept for a bug-bounty and vulnerability programme: CISA KEV entries grouped into effort clusters and ordered by risk removed per hour. Sample data.";

    canonical =
      if lang == "de"
      then base + "de/"
      else base;

    jsonld = builtins.toJSON {
      "@context" = "https://schema.org";
      "@type" = "WebPage";
      name = title;
      description = description;
      url = canonical;
      inLanguage = lang;
      isPartOf = {
        "@type" = "WebSite";
        name = "bountystash";
        url = base;
      };
    };
    ogImage =
      base
      + (
        if lang == "de"
        then "og-de.png"
        else "og.png"
      );
  in
    render ./bountystash-mockup/shell.html {
      inherit body nav langs cssHref title description canonical jsonld ogImage;
      ogImageAlt =
        if lang == "de"
        then "Konzept-Mockup: die Liste des Ausgenutzten als abarbeitbare Warteschlange, mit Aufwands-Clustern"
        else "Concept mockup: the exploited list as a work queue, grouped into effort clusters";
      htmlLang = lang;
      alternates = alternates;
      ogLocale =
        if lang == "de"
        then "de_DE"
        else "en_GB";
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

  # Share cards. Rendered at build time so the unfurl is a real 1200x630 PNG —
  # Slack, LinkedIn and X all ignore an SVG og:image. One card per locale, since
  # the headline is the whole point of the card.
  fontMono = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono.ttf";
  fontMonoBold = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono-Bold.ttf";

  card = pkgs.runCommand "mockup-og" {nativeBuildInputs = [pkgs.imagemagick];} ''
    mkdir -p $out
    card() {
      dest=$1; kicker=$2; line1=$3; line2=$4; sub=$5
      magick -size 1200x630 xc:'#080a09' \
        -fill '#b8f36b' -draw 'rectangle 0,0 10,630' \
        -font ${fontMono} -pointsize 26 -kerning 5 -fill '#5ee8c0' -annotate +80+120 "$kicker" \
        -font ${fontMonoBold} -kerning 0 -pointsize 60 -fill '#e6f2ec' -annotate +80+252 "$line1" \
        -annotate +80+330 "$line2" \
        -font ${fontMono} -pointsize 30 -fill '#8ba49b' -annotate +80+436 "$sub" \
        -fill '#2b3833' -draw 'rectangle 80,512 1120,513' \
        -pointsize 30 -fill '#b8f36b' -annotate +80+576 'concept.bountystash.com' \
        "$dest"
    }
    card $out/og.png 'CONCEPT MOCKUP · SAMPLE DATA' 'The exploited list,' 'as a queue you can close.' 'CISA KEV · effort clusters · patch order'
    card $out/og-de.png 'KONZEPT-MOCKUP · BEISPIELDATEN' 'Die Liste des Ausgenutzten,' 'als Warteschlange.' 'CISA KEV · Aufwands-Cluster · Patch-Reihenfolge'
  '';

  cssFile = pkgs.writeText "mockup-style.css" css;
  enFile = pkgs.writeText "mockup-index.html" en;
  deFile = pkgs.writeText "mockup-de.html" de;
in
  pkgs.runCommand "bountystash-mockup" {} ''
    mkdir -p $out/de
    install -m 0644 ${cssFile} $out/style.css
    install -m 0644 ${card}/og.png $out/og.png
    install -m 0644 ${card}/og-de.png $out/og-de.png
    install -m 0644 ${enFile} $out/index.html
    install -m 0644 ${deFile} $out/de/index.html
    cat > $out/robots.txt <<'EOF'
    User-agent: *
    Allow: /

    Sitemap: ${base}sitemap.xml
    EOF
    cat > $out/sitemap.xml <<'EOF'
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
      <url>
        <loc>${base}</loc>
        <xhtml:link rel="alternate" hreflang="en" href="${base}"/>
        <xhtml:link rel="alternate" hreflang="de" href="${base}de/"/>
        <xhtml:link rel="alternate" hreflang="x-default" href="${base}"/>
        <changefreq>monthly</changefreq>
      </url>
      <url>
        <loc>${base}de/</loc>
        <xhtml:link rel="alternate" hreflang="en" href="${base}"/>
        <xhtml:link rel="alternate" hreflang="de" href="${base}de/"/>
        <xhtml:link rel="alternate" hreflang="x-default" href="${base}"/>
        <changefreq>monthly</changefreq>
      </url>
    </urlset>
    EOF
    cat > $out/404.html <<'EOF'
    <!doctype html><html lang="en"><meta charset="utf-8"><title>Not found</title>
    <body style="font:15px ui-monospace,monospace;padding:4rem;max-width:40rem">
    <h1>404</h1><p>No such page. / Keine solche Seite.</p><p><a href="/">bountystash mockup</a></p>
    EOF
    echo "bountystash-mockup: $(find $out -type f | wc -l) files, $(du -sb $out | cut -f1) bytes, en+de"
  ''
