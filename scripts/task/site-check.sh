#!/usr/bin/env bash
# scripts/task/site-check.sh — assert the crawlable surface of a published site.
#
#   site-check.sh HOST [PATH...]
#
# Resolves through 1.1.1.1 and pins the answer with --resolve. This fleet's local
# resolver keeps a cached NXDOMAIN for hostnames added to Cloudflare the same day,
# which makes a healthy site look dead. Checks each page, its advertised og:image,
# robots.txt and sitemap.xml, then exits non-zero on any failure.
set -uo pipefail

host=${1:?usage: site-check.sh HOST [PATH...]}
shift
[ "$#" -eq 0 ] && set -- /

ip=$(dig +short @1.1.1.1 "$host" | grep -E '^[0-9]' | sed -n 1p)
if [ -z "$ip" ]; then
  echo "FAIL $host: 1.1.1.1 returns no A record"
  exit 1
fi

ok=0
bad=0
verdict() {
  if [ "$1" -eq 0 ]; then
    printf 'ok   %s\n' "$2"
    ok=$((ok + 1))
  else
    printf 'FAIL %s\n' "$2"
    bad=$((bad + 1))
  fi
}

get() { curl -s --max-time 25 --resolve "$host:443:$ip" "https://$host$1"; }
code() { curl -s -o /dev/null -w '%{http_code}' --max-time 25 --resolve "$host:443:$ip" "https://$host$1"; }

for path in "$@"; do
  page=$(get "$path")
  status=$(code "$path")
  if [ "$status" = "200" ]; then verdict 0 "$host$path returns 200 (got $status)"; else verdict 1 "$host$path returns 200 (got $status)"; fi
  printf '%s' "$page" | grep -q 'rel="canonical"'
  verdict $? "$host$path has rel=canonical"
  printf '%s' "$page" | grep -q 'property="og:image"'
  verdict $? "$host$path has og:image"
  printf '%s' "$page" | grep -q 'name="robots" content="index'
  verdict $? "$host$path asks to be indexed"
  printf '%s' "$page" | grep -q 'hreflang="de"'
  verdict $? "$host$path carries hreflang alternates"

  og=$(printf '%s' "$page" | grep -o 'property="og:image" content="[^"]*"' | sed -n 1p | sed 's/.*content="//; s/"$//')
  if [ -z "$og" ]; then
    verdict 1 "$host$path advertises no og:image"
  else
    case "$og" in
      "https://$host"/*)
        got=$(curl -s -o /dev/null -w '%{http_code} %{content_type}' --max-time 25 --resolve "$host:443:$ip" "$og")
        if [ "$got" = "200 image/png" ]; then verdict 0 "$og serves 200 image/png (got $got)"; else verdict 1 "$og serves 200 image/png (got $got)"; fi
        ;;
      *)
        verdict 1 "$og is not served from $host"
        ;;
    esac
  fi
done

robots=$(get /robots.txt)
# An empty body is a failed fetch, not a permissive robots.txt: without this the
# `Disallow: /` branch below records a pass for a site that answered nothing.
# CRLF is stripped first because `^Disallow: /$` cannot match a line ending in \r.
if [ -n "$robots" ]; then
  verdict 0 "$host/robots.txt answered a body"
else
  verdict 1 "$host/robots.txt answered a body"
fi
robots=${robots//$'\r'/}
printf '%s' "$robots" | grep -q 'Sitemap:'
verdict $? "$host/robots.txt names a sitemap"
# `[ $? -ne 0 ]` reads the exit status of the test it is inside, not the grep's,
# so the old form was always 0: this line could never fail. Branch on the grep.
if printf '%s' "$robots" | grep -qi '^Disallow: /$'; then
  verdict 1 "$host/robots.txt blocks everything (Disallow: /)"
else
  verdict 0 "$host/robots.txt does not block everything"
fi

sitemap=$(get /sitemap.xml)
printf '%s' "$sitemap" | python3 -c 'import sys, xml.dom.minidom; xml.dom.minidom.parseString(sys.stdin.read())' 2>/dev/null
verdict $? "$host/sitemap.xml parses as XML"
locs=$(printf '%s' "$sitemap" | grep -c '<loc>')
[ "$locs" -ge 2 ]
verdict $? "$host/sitemap.xml lists $locs URLs (want at least 2)"

printf '\n%s: %d ok, %d failed\n' "$host" "$ok" "$bad"
[ "$bad" -eq 0 ]
