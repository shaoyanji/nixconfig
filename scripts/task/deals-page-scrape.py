#!/usr/bin/env python3
"""Read the deals off a JS-rendered page: price, original price, discount.

Deal boards and retailer category pages build their price grid client-side, so a
plain GET returns a shell and the numbers only exist after a browser runs. This
reads the page through the widest layer that can answer, in cost order:

  browser    agent-browser (headless Chrome): open, read the cards, close
  firecrawl  POST /v1/scrape, markdown back
  context    POST /v1/web/scrape on api.context.dev, markdown back
  tavily     POST /extract, raw content back
  http       a plain GET — enough for a server-rendered page, and the control

Every card becomes one deal:

  title, price, original_price, discount_pct, merchant, url, category

The price pair is the judgement call. A card that shows two amounts is a deal
(original = the higher, price = the lower); a card with one amount and a `-30%`
marker computes the original from the discount; a card with one amount and no
marker is a price, not a deal, and is dropped unless `--keep-unpriced-deals`
asks for it. That is deliberate: a list of retail prices reported as deals is
worse than a short list.

Prices are read in the formats shops actually print — `1.299,00 €`, `$1,299.00`,
`CHF 1'299.–` — because a parser that only knows the dot-decimal form reads a
German 1.299 as one euro and produces a hundred-fold discount.
"""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from html.parser import HTMLParser

UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/131 Safari/537.36"
)

CURRENCY_SYMBOLS = {"€": "EUR", "$": "USD", "£": "GBP"}
CURRENCY_WORDS = {"CHF": "CHF", "EUR": "EUR", "USD": "USD", "GBP": "GBP"}

MONEY = re.compile(
    r"(?P<pre>€|\$|£|\bCHF\b|\bEUR\b|\bUSD\b|\bGBP\b)?\s*"
    # The number may not continue an alphanumeric token: in `WH-1000XM5 $279`
    # the `5` is part of the model name, not a five-dollar price.
    r"(?P<num>(?<![A-Za-z0-9])(?:\d{1,3}(?:[.,'’]\d{3})*(?:[,.]\d{1,2})?|\d+(?:[,.]\d{1,2})?))"
    r"\s*(?P<post>€|\$|£|\bCHF\b|\bEUR\b|\bUSD\b|\bGBP\b)?",
    re.I,
)
PERCENT_OFF = re.compile(
    r"(?:-|−|–)\s*(?P<a>\d{1,2})\s*%|(?P<b>\d{1,2})\s*%\s*(?:off|rabatt|g(?:ü|u)nstiger|less|billiger)",
    re.I,
)
PROMO_PREFIX = re.compile(r"^\s*(?:-|−|–)?\s*\d{1,2}\s*%\s*(?:off|rabatt)?\s*", re.I)

CATEGORIES = {
    "laptop": (
        r"laptop|notebook|macbook|thinkpad|chromebook|ideapad|thinkbook|elitebook|"
        r"zenbook|vivobook|inspiron|xps\b|latitude|pavilion|surface laptop"
    ),
    "gpu": r"\bgpu\b|grafikkarte|geforce|rtx\b|radeon|rx\s?\d{3,4}",
    "monitor": r"monitor|bildschirm|display\b|ultrawide",
    "tv": r"\btv\b|fernseher|oled|qled",
    "storage": r"\bssd\b|\bnvme\b|festplatte|hard drive|\bhdd\b|microsd",
    "audio": r"kopfh(?:ö|o)rer|headphone|earbud|in-ear|headset|lautsprecher|speaker",
    "console": r"\bkonsole\b|console|playstation|\bps5\b|xbox|nintendo|switch",
    "phone": r"smartphone|handy|iphone|pixel\b|galaxy s\d",
    "camera": r"kamera|camera|lens|objektiv|gopro",
    "network": r"router|fritzbox|mesh|wlan|repeater|switch\b.{0,10}port",
    "peripherals": r"tastatur|keyboard|\bmaus\b|\bmouse\b|webcam|dock",
    "tablet": r"tablet|\bipad\b|galaxy tab",
    "cpu": r"\bcpu\b|prozessor|ryzen|core i[3579]|apple m\d",
}

NOT_A_DEAL = re.compile(
    r"\b(shipping|versand|delivery|lieferung|newsletter|abonn|subscribe|"
    r"gift card|geschenkkarte|financing|ratenzahlung|klarna)\b",
    re.I,
)
# `$5 off $40` is a coupon threshold, not a price and an original price, and a
# deal feed's headline is mostly this shape.
COUPON = re.compile(r"\$\s?\d[\d.,]*\s+off\s+\$|extra\s+\$\s?\d[\d.,]*\s+off", re.I)
NAV_TITLES = {
    "all",
    "deals",
    "home",
    "learn more",
    "mehr erfahren",
    "more",
    "next",
    "previous",
    "shop now",
    "zum shop",
    "alle",
    "filter",
}


# -- prices ----------------------------------------------------------------


def normalize_amount(raw: str) -> float | None:
    """`1.299,00` / `1,299.00` / `1'299` / `999.–` to a number.

    The last separator present is the decimal one: a German price uses `.` for
    thousands and `,` for cents, and the reverse for English. A single `.` with
    three digits after it is thousands (`1.299`), which is the case that made a
    1,299 € laptop read as 1.299 €.
    """
    text = (raw or "").strip().replace("'", "").replace("’", "").replace(" ", "")
    if not text:
        return None
    text = re.sub(r"[.–-]+$", "", text)
    has_dot, has_comma = "." in text, "," in text
    if has_dot and has_comma:
        decimal = "," if text.rfind(",") > text.rfind(".") else "."
        thousands = "." if decimal == "," else ","
        text = text.replace(thousands, "").replace(decimal, ".")
    elif has_comma:
        head, _, tail = text.rpartition(",")
        text = f"{head}.{tail}" if len(tail) in (1, 2) else text.replace(",", "")
    elif has_dot:
        head, _, tail = text.rpartition(".")
        text = text if len(tail) in (1, 2) else f"{head}{tail}"
    try:
        value = float(text)
    except ValueError:
        return None
    return value if 0 < value < 1_000_000 else None


def find_prices(text: str):
    """Money in a text, as `(currency, amount)` pairs, in page order."""
    found = []
    for match in MONEY.finditer(text or ""):
        pre, post = match.group("pre"), match.group("post")
        if not pre and not post:
            continue  # a bare number is a size, a year or a count, not a price
        symbol = pre or post
        currency = CURRENCY_SYMBOLS.get(symbol.upper(), CURRENCY_WORDS.get(symbol.upper(), ""))
        amount = normalize_amount(match.group("num"))
        if amount is None:
            continue
        found.append((currency or "EUR", amount))
    # Collapse a repeat of the same amount in one card ("999,00 € 999,00 €").
    seen, unique = set(), []
    for currency, amount in found:
        if (currency, amount) in seen:
            continue
        seen.add((currency, amount))
        unique.append((currency, amount))
    return unique


def percent_off(text: str) -> int | None:
    match = PERCENT_OFF.search(text or "")
    if not match:
        return None
    value = int(match.group("a") or match.group("b"))
    return value if 1 <= value <= 95 else None


# -- identity --------------------------------------------------------------


# Boards do not link the shop, they link their own click tracker, and the shop
# survives only inside a query parameter: `cc.techbargains.com/...?url=https%3A
# %2F%2Fwww.amazon.com%2F...`. Reading the host alone files every deal under
# `cc`.
REDIRECT_PARAMS = {
    "url", "u", "target", "tgt", "dest", "destination", "redirect", "redirect_url",
    "redirect_uri", "redir", "r", "goto", "go", "link", "to", "out", "offer",
    "offer_url", "deeplink", "deep_link", "deepl", "lo", "dl",
}

# Names that are not shops even after unwrapping: shorteners with no target.
LINK_SHORTENERS = {"bit.ly", "bitly.com", "t.co", "ow.ly", "tinyurl.com", "lnk.to", "is.gd", "buff.ly", "rb.gy"}

# A host label is not always the shop's name in the text a person would use.
MERCHANT_ALIASES = {
    "amzn": "amazon", "amazon": "amazon", "amzn.to": "amazon", "ebay": "ebay", "ebay.us": "ebay",
    "walmart": "walmart", "bestbuy": "bestbuy", "newegg": "newegg", "target": "target",
    "aliexpress": "aliexpress", "otto": "otto", "mediamarkt": "mediamarkt", "saturn": "saturn",
    "notebooksbilliger": "notebooksbilliger", "cyberport": "cyberport", "alternate": "alternate",
    "idealo": "idealo", "geizhals": "geizhals", "kaufda": "kaufda", "coolblue": "coolblue",
}


def unwrap_redirect(url: str, hops: int = 2) -> str:
    """The shop URL a click tracker points at, when it carries one."""
    current = (url or "").strip()
    for _ in range(hops + 1):
        query = urllib.parse.parse_qsl(urllib.parse.urlsplit(current).query, keep_blank_values=False)
        target = ""
        for key, value in query:
            if not value.lower().startswith(("http://", "https://")):
                continue
            if key.lower() in REDIRECT_PARAMS or key.lower().endswith("_url"):
                target = value
                break
        if not target or target == current:
            break
        current = target
    return current


def merchant_from(url: str) -> str:
    host = urllib.parse.urlsplit(unwrap_redirect(url)).netloc.lower().removeprefix("www.")
    if not host or host in LINK_SHORTENERS:
        return ""
    labels = host.split(".")
    label = labels[0]
    # `shop.samsung.com` is Samsung; `shop.example` has one label and stays.
    if label in {"deals", "deal", "shop", "shopping", "store"} and len(labels) > 2:
        label = labels[1]
    return MERCHANT_ALIASES.get(label, label)


def category_of(title: str, url: str = "") -> str:
    haystack = f"{title} {urllib.parse.urlsplit(url).path.replace('-', ' ')}".lower()
    for name, pattern in CATEGORIES.items():
        if re.search(pattern, haystack, re.I):
            return name
    return "other"


def canonical(url: str) -> str:
    parts = urllib.parse.urlsplit((url or "").strip())
    query = [
        (k, v)
        for k, v in urllib.parse.parse_qsl(parts.query, keep_blank_values=False)
        if not k.lower().startswith("utm_")
    ]
    return urllib.parse.urlunsplit(
        (
            parts.scheme.lower(),
            parts.netloc.lower().removeprefix("www."),
            parts.path.rstrip("/") or "/",
            urllib.parse.urlencode(query),
            "",
        )
    ).rstrip("/")


# -- extraction ------------------------------------------------------------


BUTTON_LABEL = re.compile(
    r"^(?:more details|get deal|reveal code|details|view deal|shop now|"
    r"zum angebot|alle angebote|buy now|jetzt kaufen)$",
    re.I,
)


def strip_markdown(text: str) -> str:
    plain = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text or "")
    return re.sub(r"[*_`#>|]+", " ", plain).strip()


def clean_title(text: str) -> str:
    plain = html.unescape(text or "")
    # A card anchor can wrap the whole tile, so the text arrives with tags and
    # leftover attributes in it; both are noise, and a tag stripped only when it
    # is short enough leaves the attribute soup behind.
    plain = re.sub(r"<[^>]*>", " ", plain)
    plain = re.sub(r"[\w:-]+=\"[^\"]*\"", " ", plain)
    plain = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", plain)  # links keep their label
    plain = re.sub(r"[*_`#>|\[\]]+", " ", plain)
    plain = PROMO_PREFIX.sub("", plain)
    # A title ends where the first money token begins — at the whole token, not
    # at its last digit, or `WH-1000XM5 $279` loses the model number.
    for money in MONEY.finditer(plain):
        if money.group("pre") or money.group("post"):
            plain = plain[: money.start()]
            break
    plain = re.split(r"\b(?:More Details|Get Deal|Reveal Code|Alle Angebote|Zum Angebot)\b", plain)[0]
    plain = re.sub(r"\s+", " ", plain).strip(" -|·—,:$€£\t")
    return plain[:140]


def deal_from_text(text: str, url: str, category: str = "", merchant: str = "", keep_single=False):
    """One card's text into a deal, or None when it is not a deal."""
    body = (text or "").strip()
    if len(body) < 6 or NOT_A_DEAL.search(body) or COUPON.search(body):
        return None
    prices = find_prices(body)
    if not prices:
        return None
    discount = percent_off(body)
    currency = prices[0][0]
    # Two amounts are the pair, whichever way round the page prints them: a
    # shop strikes the original above the sale price, a deal feed writes
    # `$499.99 ($599.99 -17%)` with the price first. Under 3% apart they are not
    # a discount and the card is refused.
    amounts = [amount for _, amount in prices]
    if len(amounts) >= 2:
        price, original = min(amounts), max(amounts)
        if original <= price * 1.03:
            return None
    elif discount:
        price = amounts[0]
        original = round(price / (1 - discount / 100), 2)
    elif keep_single:
        price, original = amounts[0], None
    else:
        return None
    if original and price > 0:
        computed = round((original - price) / original * 100) if original > price else None
        discount = discount or computed
    if discount and discount < 1:
        discount = None
    title = clean_title(body)
    if len(title) < 3 or title.lower() in NAV_TITLES:
        return None
    return {
        "title": title,
        "price": round(price, 2),
        "original_price": round(original, 2) if original else None,
        "discount_pct": discount,
        "currency": currency,
        "merchant": merchant or merchant_from(url),
        "url": canonical(url),
        "category": category or category_of(title, url),
    }


def deals_from_anchors(pairs, page_url: str, **kwargs):
    deals, seen = [], set()
    for href, text in pairs:
        url = urllib.parse.urljoin(page_url, (href or "").strip())
        if not url.startswith(("http://", "https://")):
            continue
        deal = deal_from_text(text, url, **kwargs)
        if not deal:
            continue
        # One card links its image and its title to different URLs; the price
        # and the name are what make it the same deal.
        key = (deal["title"].lower(), deal["price"], deal["original_price"])
        if key in seen:
            continue
        seen.add(key)
        deals.append(deal)
    return deals


MD_LINK = re.compile(r"\[([^\]]{1,400})\]\((https?://[^)\s]+)\)?", re.S)


def deals_from_markdown(text: str, page_url: str, **kwargs):
    """Cards from markdown: the link label plus its neighbours as one card.

    A listing puts the price outside the link — the label is `~~$49.99~~ (62%
    Off)` and the product name is the line above it — so a card is the label
    joined to the line before and the two after, exactly the text a person sees
    in one tile.
    """
    lines = text.splitlines()
    deals, seen = [], set()
    for match in MD_LINK.finditer(text):
        if match.start() > 0 and text[match.start() - 1] == "!":
            continue  # the tile's image, whose alt text is not a link card
        href = urllib.parse.urljoin(page_url, match.group(2).strip())
        if href in seen:
            continue
        seen.add(href)
        line_index = text.count("\n", 0, match.start())
        # Only the neighbours of this card: a blank line ends it, and a line
        # that is itself a link is the next card (joining it let one card's
        # "newsletter" reject its neighbour's deal).
        before, after = [], []
        for line in reversed(lines[max(0, line_index - 4) : line_index]):
            if not line.strip():
                break
            before.insert(0, line.strip())
        for line in lines[line_index + 1 : line_index + 5]:
            if not line.strip() or MD_LINK.search(line):
                break
            after.append(line.strip())
            if len(after) == 2:
                break
        label_lines = [line.strip() for line in match.group(1).splitlines() if line.strip()]
        title = " ".join(([before[-1]] if before else []) + label_lines[:1])
        # `More Details` is a button inside the card, not the card: the heading
        # link above it already names the deal, and taking the button too made
        # every deal appear twice with the wrong title.
        label_text = strip_markdown(label_lines[0] if label_lines else "").strip(" :")
        if BUTTON_LABEL.match(label_text):
            continue
        deal = deal_from_text(" ".join([title] + after[:2]), href, **kwargs)
        if not deal:
            # A card can put the price on a line of its own, separated from the
            # heading by the image and a sentence: read the window around it.
            window = []
            for line in lines[line_index + 1 : line_index + 9]:
                text_line = line.strip()
                if not text_line:
                    continue
                if text_line.startswith("#") and find_prices(text_line):
                    break
                window.append(text_line)
                if len(window) == 4:
                    break
            deal = deal_from_text(" ".join([title] + window), href, **kwargs)
        if deal:
            deals.append(deal)
    if deals:
        return deals
    for block in re.split(r"\n\s*\n", text):
        deal = deal_from_text(block, page_url, **kwargs)
        if deal:
            deals.append(deal)
    return deals


class AnchorParser(HTMLParser):
    """Anchors with their label: `title` first, then the text inside them."""

    SKIP = {"script", "style", "noscript", "svg", "iframe", "template"}

    def __init__(self):
        super().__init__()
        self.pairs = []
        self._href = None
        self._title = None
        self._text = []
        self._skip = 0

    def handle_starttag(self, tag, attrs):
        if tag in self.SKIP:
            self._skip += 1
            return
        if tag == "a":
            attributes = dict(attrs)
            self._href = attributes.get("href")
            self._title = attributes.get("title") or attributes.get("aria-label")
            self._text = []

    def handle_data(self, data):
        if self._href is not None and not self._skip:
            self._text.append(data)

    def handle_endtag(self, tag):
        if tag in self.SKIP:
            self._skip = max(0, self._skip - 1)
            return
        if tag == "a" and self._href:
            label = self._title or "".join(self._text)
            self.pairs.append((self._href, label))
            self._href = None


def deals_from_html(page: str, page_url: str, **kwargs):
    parser = AnchorParser()
    try:
        parser.feed(page)
    except Exception:  # noqa: BLE001 - a malformed page is a page with fewer anchors
        pass
    deals = deals_from_anchors(parser.pairs, page_url, **kwargs)
    return deals or deals_from_markdown(page, page_url, **kwargs)


# -- providers -------------------------------------------------------------


class Unavailable(RuntimeError):
    """This layer cannot answer here; the next one may."""


def load_keys(path: str, names) -> dict:
    wanted = set(names)
    found = {}
    try:
        with open(os.path.expanduser(path), encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                name, value = line.split("=", 1)
                if name in wanted:
                    found[name] = value.strip().strip('"').strip("'")
    except OSError:
        pass
    for name in wanted:
        if os.environ.get(name):
            found[name] = os.environ[name]
    return found


# A tile keeps its price in a sibling of the link, so the card is the nearest
# repeated container, not the anchor: reading only anchors found no price at all
# on dealnews (the tile's own innerText has it).
BROWSER_JS = (
    "JSON.stringify([...document.querySelectorAll('a[href]')].map(a=>{"
    "const box=a.closest('article,li,[class*=card],[class*=tile],[class*=deal],"
    "[class*=product],[class*=item]')||a.parentElement||a;"
    "const head=box.querySelector('h1,h2,h3,h4,h5');"
    "const name=a.getAttribute('title')||(head?String(head.innerText||'').trim():'');"
    "const t=(name?name+' ':'')+String((box.innerText||box.textContent||''))"
    ".trim().slice(0,400);"
    "return {h:a.href,t:t.trim()};})"
    ".filter(x=>x.h&&x.t&&/[\u20ac$\u00a3]/.test(x.t)).slice(0,3000))"
)


def fetch_browser(url: str, timeout: int, binary: str):
    if not shutil.which(binary):
        raise Unavailable(f"{binary} is not on PATH")
    try:
        try:
            subprocess.run(
                [binary, "open", url], check=True, timeout=timeout, capture_output=True
            )
            result = subprocess.run(
                [binary, "eval", BROWSER_JS],
                check=True,
                timeout=timeout,
                capture_output=True,
                text=True,
            )
        except subprocess.CalledProcessError as exc:
            detail = (exc.stderr or b"").decode("utf-8", "replace").strip()
            raise Unavailable(
                f"the browser could not open {url}: {detail.splitlines()[-1][:160] if detail else exc.returncode}"
            ) from exc
    finally:
        subprocess.run([binary, "close"], timeout=30, capture_output=True, check=False)
    raw = result.stdout.strip()
    if not raw:
        raise Unavailable("the browser returned no anchors")
    try:
        value = json.loads(raw)
        if isinstance(value, str):
            value = json.loads(value)
    except json.JSONDecodeError as exc:
        raise Unavailable(f"the browser answered unparsable JSON: {exc}") from exc
    return [(item.get("h"), item.get("t")) for item in value]


def fetch_markdown(provider: str, url: str, timeout: int, keys: dict) -> str:
    if provider == "firecrawl":
        key = keys.get("FIRECRAWL_API_KEY", "")
        if not key:
            raise Unavailable("FIRECRAWL_API_KEY is not set")
        endpoint = "https://api.firecrawl.dev/v1/scrape"
        body = {"url": url, "formats": ["markdown"], "onlyMainContent": True}
    elif provider == "context":
        key = keys.get("CONTEXT_API_KEY", "") or keys.get("CONTEXT_DEV_API_KEY", "")
        if not key:
            raise Unavailable("CONTEXT_API_KEY is not set")
        endpoint = "https://api.context.dev/v1/web/scrape"
        body = {
            "url": url,
            "formats": {"markdown": True},
            "sharedParams": {"mainContentOnly": True},
        }
    else:
        key = keys.get("TAVILY_API_KEY", "")
        if not key:
            raise Unavailable("TAVILY_API_KEY is not set")
        endpoint = "https://api.tavily.com/extract"
        body = {"urls": [url], "api_key": key}
    request = urllib.request.Request(
        endpoint,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {key}"},
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = json.load(response)
    if provider == "firecrawl":
        markdown = (payload.get("data") or {}).get("markdown") or ""
    elif provider == "context":
        block = payload.get("markdown") or {}
        markdown = block.get("data") or "" if block.get("success") else ""
    else:
        results = payload.get("results") or []
        markdown = (results[0].get("raw_content") if results else "") or ""
    if not markdown:
        raise Unavailable(f"{provider} returned no content")
    return markdown


def fetch_http(url: str, timeout: int) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read().decode("utf-8", "replace")


BACKENDS = ("auto", "browser", "firecrawl", "context", "tavily", "http")


def collect(url: str, backend: str, args, keys: dict, **kwargs):
    order = {
        "auto": ["browser", "firecrawl", "context", "http"],
        "browser": ["browser"],
        "firecrawl": ["firecrawl"],
        "context": ["context"],
        "tavily": ["tavily"],
        "http": ["http"],
    }[backend]
    warnings = []
    for name in order:
        try:
            if name == "browser":
                deals = deals_from_anchors(
                    fetch_browser(url, args.timeout, args.agent_browser), url, **kwargs
                )
            elif name == "http":
                deals = deals_from_html(fetch_http(url, args.timeout), url, **kwargs)
            else:
                deals = deals_from_markdown(
                    fetch_markdown(name, url, args.timeout, keys), url, **kwargs
                )
        except (
            Unavailable,
            urllib.error.URLError,
            TimeoutError,
            OSError,
            subprocess.SubprocessError,
        ) as exc:
            warnings.append(f"{name}: {str(exc)[:200]}")
            continue
        if not deals:
            warnings.append(f"{name}: no priced deals recognised")
            continue
        return deals, name, warnings
    return [], None, warnings


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Read deals (price, original price, discount) off a JS-rendered page.",
        epilog="Exits 1 when no page yielded a deal; a page can still report warnings.",
    )
    parser.add_argument("url", nargs="+", help="deal or category page URL")
    parser.add_argument("--backend", choices=BACKENDS, default="auto")
    parser.add_argument("--min-discount", type=int, default=0, help="keep deals at or above this %% off")
    parser.add_argument("--max", type=int, default=0, help="cap deals per page")
    parser.add_argument("--category", default="", help="override the inferred category")
    parser.add_argument("--merchant", default="", help="override the merchant from the URL")
    parser.add_argument("--keep-unpriced-deals", action="store_true", help="keep single-price cards")
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--agent-browser", default="agent-browser")
    parser.add_argument("--env-file", default="~/.hermes/.env")
    parser.add_argument("--out", help="write the JSON here instead of stdout")
    parser.add_argument("--json", action="store_true", help="JSON even when a terminal")
    args = parser.parse_args()

    keys = load_keys(
        args.env_file,
        ("FIRECRAWL_API_KEY", "TAVILY_API_KEY", "CONTEXT_API_KEY", "CONTEXT_DEV_API_KEY"),
    )
    results = []
    for url in args.url:
        deals, used, warnings = collect(
            url,
            args.backend,
            args,
            keys,
            category=args.category,
            merchant=args.merchant,
            keep_single=args.keep_unpriced_deals,
        )
        if args.min_discount:
            deals = [d for d in deals if (d["discount_pct"] or 0) >= args.min_discount]
        if args.max:
            deals = deals[: args.max]
        results.append(
            {
                "url": url,
                "backend": used,
                "fetched_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                "count": len(deals),
                "deals": deals,
                "warnings": warnings,
            }
        )

    payload = json.dumps(results, indent=2)
    if args.out:
        with open(os.path.expanduser(args.out), "w", encoding="utf-8") as handle:
            handle.write(payload + "\n")
    if args.json or args.out or not sys.stdout.isatty():
        print(payload)
    else:
        for page in results:
            print(f"{page['url']}  [{page['backend'] or 'unavailable'}]  {page['count']}")
            for deal in page["deals"]:
                was = f"{deal['original_price']:,.2f} → " if deal["original_price"] else ""
                off = f"  -{deal['discount_pct']}%" if deal["discount_pct"] else ""
                print(f"  {deal['title']}  {was}{deal['price']:,.2f} {deal['currency']}{off}")
            for warning in page["warnings"]:
                print(f"  ! {warning}")
    return 0 if any(page["count"] for page in results) else 1


if __name__ == "__main__":
    sys.exit(main())
