#!/usr/bin/env python3
"""Fixture for scripts/task/deals-page-scrape.py.

The two failures that matter are a wrong price and a false deal, so the cases
are the formats shops print (`1.299,00 €` is 1299, not 1.299), the discount that
has to be computed from a pair, and every card that must not be called a deal.
"""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "deals_page_scrape", ROOT / "scripts" / "task" / "deals-page-scrape.py"
)
deals = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(deals)

PAGE = "https://www.mydealz.de/new"


class AmountTest(unittest.TestCase):
    def test_german_decimal_comma(self):
        self.assertEqual(deals.normalize_amount("1.299,00"), 1299.0)

    def test_english_decimal_dot(self):
        self.assertEqual(deals.normalize_amount("1,299.00"), 1299.0)

    def test_dot_with_three_digits_is_thousands(self):
        self.assertEqual(deals.normalize_amount("1.299"), 1299.0)

    def test_swiss_apostrophe_and_dash_tail(self):
        self.assertEqual(deals.normalize_amount("1'299.–"), 1299.0)

    def test_plain_integer(self):
        self.assertEqual(deals.normalize_amount("749"), 749.0)

    def test_nonsense_is_none(self):
        self.assertIsNone(deals.normalize_amount(""))
        self.assertIsNone(deals.normalize_amount("abc"))


class FindPricesTest(unittest.TestCase):
    def test_symbol_before_and_after(self):
        self.assertEqual(
            deals.find_prices("Lenovo IdeaPad 5 1.299,00 € now 999,00 €"),
            [("EUR", 1299.0), ("EUR", 999.0)],
        )

    def test_dollar_and_pound(self):
        self.assertEqual(deals.find_prices("$1,299.00"), [("USD", 1299.0)])
        self.assertEqual(deals.find_prices("£899"), [("GBP", 899.0)])

    def test_chf_word_currency(self):
        self.assertEqual(deals.find_prices("CHF 1'299.–"), [("CHF", 1299.0)])

    def test_bare_numbers_are_not_prices(self):
        self.assertEqual(deals.find_prices("27 Zoll, 2024, 16 GB"), [])

    def test_repeat_of_one_amount_collapses(self):
        self.assertEqual(deals.find_prices("999,00 € 999,00 €"), [("EUR", 999.0)])


class DiscountTest(unittest.TestCase):
    def test_minus_percent(self):
        self.assertEqual(deals.percent_off("RTX 4070 -30%"), 30)

    def test_percent_off_word(self):
        self.assertEqual(deals.percent_off("25% off today"), 25)
        self.assertEqual(deals.percent_off("30 % Rabatt"), 30)

    def test_none_without_a_marker(self):
        self.assertIsNone(deals.percent_off("Lenovo IdeaPad 5"))

    def test_out_of_range_is_refused(self):
        self.assertIsNone(deals.percent_off("-99%"))
        self.assertIsNone(deals.percent_off("-0%"))


class TitleTest(unittest.TestCase):
    def test_title_stops_at_the_price(self):
        self.assertEqual(
            deals.clean_title("Lenovo IdeaPad 5 Pro 1.299,00 € 999,00 €"),
            "Lenovo IdeaPad 5 Pro",
        )

    def test_promo_prefix_is_dropped(self):
        self.assertEqual(deals.clean_title("-30% Sony WH-1000XM5 349,00 €"), "Sony WH-1000XM5")

    def test_markdown_noise_is_dropped(self):
        self.assertEqual(deals.clean_title("**Samsung 990 Pro** 2 TB"), "Samsung 990 Pro 2 TB")


class DealJudgementTest(unittest.TestCase):
    def test_two_prices_are_a_deal_with_computed_discount(self):
        deal = deals.deal_from_text(
            "Lenovo IdeaPad 5 1.299,00 € 999,00 €", "https://shop.example/laptop-5"
        )
        self.assertIsNotNone(deal)
        self.assertEqual(deal["price"], 999.0)
        self.assertEqual(deal["original_price"], 1299.0)
        self.assertEqual(deal["discount_pct"], 23)

    def test_one_price_plus_marker_computes_the_original(self):
        deal = deals.deal_from_text(
            "Sony WH-1000XM5 -30% 279,00 €", "https://shop.example/wh1000xm5"
        )
        self.assertEqual(deal["price"], 279.0)
        self.assertEqual(deal["original_price"], 398.57)
        self.assertEqual(deal["discount_pct"], 30)

    def test_single_price_without_a_marker_is_not_a_deal(self):
        self.assertIsNone(
            deals.deal_from_text("Sony WH-1000XM5 349,00 €", "https://shop.example/x")
        )

    def test_single_price_can_be_kept_on_request(self):
        deal = deals.deal_from_text(
            "Sony WH-1000XM5 349,00 €", "https://shop.example/x", keep_single=True
        )
        self.assertIsNotNone(deal)
        self.assertIsNone(deal["original_price"])

    def test_coupon_thresholds_are_not_a_price_pair(self):
        self.assertIsNone(
            deals.deal_from_text(
                "Up to 75% off + extra $5 off $40 at eBay", "https://deals.example/ebay"
            )
        )

    def test_shipping_and_subscriptions_are_not_deals(self):
        self.assertIsNone(
            deals.deal_from_text("Versand 4,99 €", "https://shop.example/shipping")
        )
        self.assertIsNone(
            deals.deal_from_text("Newsletter 0,00 €", "https://shop.example/news")
        )

    def test_two_amounts_within_three_percent_are_not_a_deal(self):
        self.assertIsNone(
            deals.deal_from_text("Cable 9,99 € 10,19 €", "https://shop.example/cable")
        )

    def test_price_first_card_is_read_the_same_way(self):
        deal = deals.deal_from_text(
            "RTX 4070 Super $499.99 ($599.99 -17%)", "https://deals.example/rtx"
        )
        self.assertEqual(deal["price"], 499.99)
        self.assertEqual(deal["original_price"], 599.99)
        self.assertEqual(deal["discount_pct"], 17)


class IdentityTest(unittest.TestCase):
    def test_merchant_is_the_registrable_label(self):
        self.assertEqual(deals.merchant_from("https://www.mediamarkt.de/de/product"), "mediamarkt")
        self.assertEqual(deals.merchant_from("https://geizhals.de/x"), "geizhals")

    def test_category_from_title(self):
        self.assertEqual(deals.category_of("Lenovo IdeaPad 5 Pro"), "laptop")
        self.assertEqual(deals.category_of("GeForce RTX 4070 Super"), "gpu")
        self.assertEqual(deals.category_of("Sony WH-1000XM5 Kopfhörer"), "audio")
        self.assertEqual(deals.category_of("Samsung 990 Pro NVMe SSD"), "storage")
        self.assertEqual(deals.category_of("Something odd"), "other")


class AnchorExtractionTest(unittest.TestCase):
    def test_same_deal_twice_is_one(self):
        found = deals.deals_from_anchors(
            [
                ("https://shop.example/p/1", "Lenovo IdeaPad 5 1.299,00 € 999,00 €"),
                ("https://shop.example/p/1?utm_source=x", "Lenovo IdeaPad 5 1.299,00 € 999,00 €"),
            ],
            PAGE,
        )
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0]["merchant"], "shop")

    def test_relative_hrefs_resolve(self):
        found = deals.deals_from_anchors(
            [("/p/2", "GeForce RTX 4070 599,00 € 549,00 €")], "https://shop.example/deals"
        )
        self.assertEqual(found[0]["url"], "https://shop.example/p/2")

    def test_links_without_prices_are_dropped(self):
        self.assertEqual(deals.deals_from_anchors([("/about", "About us")], PAGE), [])


class MarkdownTest(unittest.TestCase):
    def test_link_label_carries_the_prices(self):
        markdown = (
            "# Deals\n\n"
            "[**Samsung 990 Pro 2 TB** 189,00 € 129,00 €](https://shop.example/ssd)\n\n"
            "[Newsletter](https://shop.example/news)\n"
        )
        found = deals.deals_from_markdown(markdown, PAGE)
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0]["category"], "storage")
        self.assertEqual(found[0]["discount_pct"], 32)


class ButtonLinkTest(unittest.TestCase):
    def test_a_more_details_button_is_not_a_card(self):
        markdown = (
            '### [Sony WH-1000XM5 $279.00](https://shop.example/wh)\n\n'
            '![Sony](https://shop.example/wh.jpg)\n\n'
            '[More Details](https://shop.example/wh-details)\n\n'
            '~~$398.00~~ **(30% Off)**\n'
        )
        found = deals.deals_from_markdown(markdown, PAGE)
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0]["title"], "Sony WH-1000XM5")
        self.assertEqual(found[0]["price"], 279.0)
        self.assertEqual(found[0]["original_price"], 398.0)


class FallbackTest(unittest.TestCase):
    def test_missing_browser_falls_through_to_http(self):
        args = type("Args", (), {"timeout": 5, "agent_browser": "definitely-not-a-binary"})()
        original = deals.fetch_http
        deals.fetch_http = lambda url, timeout: (
            '<a href="https://shop.example/tv">LG OLED 55 1.499,00 € 1.199,00 €</a>'
        )
        try:
            found, used, warnings = deals.collect(
                PAGE, "auto", args, {}, category="", merchant="", keep_single=False
            )
        finally:
            deals.fetch_http = original
        self.assertEqual(used, "http")
        self.assertEqual(found[0]["category"], "tv")
        self.assertEqual(found[0]["price"], 1199.0)
        self.assertTrue(any(w.startswith("browser:") for w in warnings))


if __name__ == "__main__":
    unittest.main()
