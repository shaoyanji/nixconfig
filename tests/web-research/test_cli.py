#!/usr/bin/env python3
"""Fixture for scripts/task/web-research.py.

Providers are mocked at the HTTP edge: the shapes below are copied from live
answers (context `description`/`relevance`, firecrawl `data` list, tavily
`content`/`score`), because mistaking one field for another is the failure mode
that matters.
"""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("web_research", ROOT / "scripts" / "task" / "web-research.py")
research = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(research)

TAVILY = {
    "query": "nix flake devshell",
    "results": [
        {
            "url": "https://discourse.nixos.org/t/devshell/67351",
            "title": "Nix flake: devShell with python modules",
            "content": "Title: Nix flake\n# Nix flake: devShell with python modules from GitHub",
            "score": 0.81,
        }
    ],
}
CONTEXT = {
    "results": [
        {
            "url": "https://discourse.nixos.org/t/devshell/67351/?utm_source=ctx",
            "title": "Flake equivalent for nix-shell",
            "description": "I am currently defining shells with mkShell into the devShells outputs of my flakes.",
            "relevance": "medium",
        },
        {
            "url": "https://github.com/jeffkreeftmeijer/devshells/blob/main/nodejs/flake.nix",
            "title": "devshells/nodejs/flake.nix at main",
            "description": "A repository of development environments.",
            "relevance": "medium",
        },
    ]
}
FIRECRAWL = {
    "success": True,
    "data": [
        {"url": "https://news.ycombinator.com/item?id=32169454", "title": "About using Nix in my workflow", "description": "Flakes provide a consistent entry point."}
    ],
    "warnings": ["/v1/search is deprecated, use v2"],
}


class IdentityTest(unittest.TestCase):
    def test_canonical_strips_tracking_and_slash(self):
        self.assertEqual(
            research.canonical("https://WWW.Example.com/a/b/?utm_source=x&ref=y&page=2#top"),
            "https://example.com/a/b?page=2",
        )

    def test_two_provider_urls_are_one_page(self):
        self.assertEqual(
            research.canonical("https://discourse.nixos.org/t/devshell/67351"),
            research.canonical("https://www.discourse.nixos.org/t/devshell/67351/?utm_source=ctx"),
        )


class ParserTest(unittest.TestCase):
    def test_tavily_uses_content_and_score(self):
        found = research.from_tavily(TAVILY)
        self.assertEqual(found[0]["snippet"].startswith("Title: Nix flake"), True)
        self.assertEqual(found[0]["score"], 0.81)

    def test_context_uses_description_and_relevance(self):
        found = research.from_context(CONTEXT)
        self.assertEqual(found[0]["snippet"].startswith("I am currently defining shells"), True)
        self.assertEqual(found[0]["score"], "medium")

    def test_firecrawl_accepts_a_list_and_a_web_dict(self):
        self.assertEqual(len(research.from_firecrawl(FIRECRAWL)), 1)
        wrapped = {"data": {"web": FIRECRAWL["data"], "news": []}}
        self.assertEqual(len(research.from_firecrawl(wrapped)), 1)

    def test_results_without_a_url_are_dropped(self):
        self.assertEqual(research.from_tavily({"results": [{"title": "x"}]}), [])


class MergeTest(unittest.TestCase):
    def setUp(self):
        self.results = []
        for provider, parser, payload in (
            ("tavily", research.from_tavily, TAVILY),
            ("context", research.from_context, CONTEXT),
            ("firecrawl", research.from_firecrawl, FIRECRAWL),
        ):
            for item in parser(payload):
                item["provider"] = provider
                self.results.append(item)

    def test_dedupe_keeps_both_witnesses(self):
        merged = research.merge(self.results)
        self.assertEqual(len(merged), 3)
        self.assertEqual(merged[0]["providers"], ["tavily", "context"])

    def test_the_longer_snippet_wins(self):
        merged = research.merge(self.results)
        self.assertIn("mkShell", merged[0]["snippet"])

    def test_a_source_without_a_title_still_cites(self):
        entries, sources = research.cite([{"url": "https://x", "id": ""}], accessed="T")
        self.assertEqual(sources[0], {"id": "s1", "url": "https://x", "title": "", "accessed": "T"})

    def test_citation_ids_are_stable_and_sourced(self):
        entries, sources = research.cite(research.merge(self.results), accessed="2026-11-26T00:00:00Z")
        self.assertEqual([e["id"] for e in entries], ["s1", "s2", "s3"])
        self.assertEqual([s["id"] for s in sources], ["s1", "s2", "s3"])
        self.assertEqual(sources[0]["url"], "https://discourse.nixos.org/t/devshell/67351")
        self.assertEqual(sources[0]["accessed"], "2026-11-26T00:00:00Z")


class ProviderCallTest(unittest.TestCase):
    def test_missing_key_is_unavailable_not_a_crash(self):
        with self.assertRaises(research.Unavailable) as caught:
            research.search_provider("tavily", "q", 3, {}, 10)
        self.assertIn("TAVILY_API_KEY", str(caught.exception))

    def test_search_marks_the_provider_and_flags_deprecation(self):
        keys = {"FIRECRAWL_API_KEY": "k"}
        with mock.patch.object(research, "post_json", return_value=FIRECRAWL):
            results, warnings = research.search_provider("firecrawl", "q", 3, keys, 10)
        self.assertEqual(results[0]["provider"], "firecrawl")
        self.assertEqual(len(warnings), 1)
        self.assertIn("deprecated", warnings[0])

    def test_context_key_falls_back_to_the_dev_name(self):
        self.assertEqual(research.context_key({"CONTEXT_DEV_API_KEY": "k"}), "k")

    def test_an_empty_extract_is_a_refusal(self):
        with mock.patch.object(research, "post_json", return_value={"data": {"markdown": ""}}):
            with self.assertRaises(research.Unavailable):
                research.extract_markdown("firecrawl", "https://x", {"FIRECRAWL_API_KEY": "k"}, 10)


class BrowserTest(unittest.TestCase):
    def test_local_runs_the_binary(self):
        self.assertEqual(
            research.browser_argv("local", "agent-browser", ["open", "https://x"]),
            ["agent-browser", "open", "https://x"],
        )

    def test_browser_text_unquotes_the_cli_json_string(self):
        calls = []

        def fake(via, binary, args, timeout):
            calls.append(args[0])
            return '"This domain is for use in examples."' if args[0] == "eval" else ""

        with mock.patch.object(research, "run_browser", fake):
            self.assertEqual(
                research.browser_text("clanker", "agent-browser", "https://example.com", 10),
                "This domain is for use in examples.",
            )
        self.assertEqual(calls, ["open", "eval", "close"])

    def test_clanker_wraps_the_command_and_quotes_it(self):
        argv = research.browser_argv("clanker", "agent-browser", ["open", "https://x?a=1&b=2"])
        self.assertEqual(argv[:5], ["task", "--silent", "instabox:exec", "--", "clanker"])
        self.assertIn("$HOME/.nix-profile/bin", argv[5])
        self.assertIn("'https://x?a=1&b=2'", argv[5])


class TitleTest(unittest.TestCase):
    def test_first_h1_becomes_the_title(self):
        self.assertEqual(research.title_from_markdown("intro\n\n# Nix manual\nbody"), "Nix manual")

    def test_no_heading_means_no_title(self):
        self.assertEqual(research.title_from_markdown("just text"), "")


class HealthTest(unittest.TestCase):
    def page(self, **overrides):
        base = {"title": "Example", "ready": "complete", "textChars": 900, "links": 12, "scripts": 4, "appMount": False}
        base.update(overrides)
        return base

    def test_a_rendered_page_is_healthy(self):
        self.assertEqual(research.health_verdict(self.page()), (True, []))

    def test_a_js_shell_is_not(self):
        ok, problems = research.health_verdict(self.page(textChars=20, appMount=True))
        self.assertFalse(ok)
        self.assertIn("app shell never hydrated", problems)
        self.assertTrue(any("rendered chars" in p for p in problems))

    def test_http_error_and_missing_title_are_problems(self):
        ok, problems = research.health_verdict(self.page(http_status=403, title=" "))
        self.assertFalse(ok)
        self.assertIn("http 403", problems)
        self.assertIn("no title", problems)


class OutputTest(unittest.TestCase):
    def test_fallback_toon_is_a_flat_record(self):
        text = research.fallback_toon({"mode": "search", "count": 1, "results": [{"id": "s1"}]})
        self.assertIn("mode: search", text)
        self.assertIn("[1]{id}:", text)

    def test_toon_uses_the_encoder_when_present(self):
        with mock.patch.object(research.shutil, "which", return_value="/bin/toon"), mock.patch.object(
            research.subprocess, "run", return_value=mock.Mock(stdout="mode: search\n")
        ):
            self.assertEqual(research.to_toon({"mode": "search"}), "mode: search")

    def test_toon_falls_back_when_the_encoder_fails(self):
        with mock.patch.object(research.shutil, "which", return_value="/bin/toon"), mock.patch.object(
            research.subprocess, "run", side_effect=research.subprocess.CalledProcessError(1, "toon")
        ):
            self.assertIn("mode: search", research.to_toon({"mode": "search"}))


class KeysTest(unittest.TestCase):
    def test_keys_come_from_the_env_file_and_the_environment(self):
        with tempfile.NamedTemporaryFile("w", suffix=".env", delete=False) as handle:
            handle.write('FIRECRAWL_API_KEY="fc"\n# comment\nOTHER=no\nTAVILY_API_KEY=tv\n')
            path = handle.name
        with mock.patch.dict(research.os.environ, {}, clear=False):
            research.os.environ.pop("FIRECRAWL_API_KEY", None)
            research.os.environ.pop("TAVILY_API_KEY", None)
            keys = research.load_keys(path)
        self.assertEqual(keys["FIRECRAWL_API_KEY"], "fc")
        self.assertEqual(keys["TAVILY_API_KEY"], "tv")
        self.assertNotIn("OTHER", keys)


class SearchModeTest(unittest.TestCase):
    def run_main(self, argv):
        out = io.StringIO()
        with mock.patch.object(sys, "argv", argv), mock.patch.object(
            research, "load_keys", return_value={"TAVILY_API_KEY": "k"}
        ), contextlib.redirect_stdout(out):
            code = research.main()
        return code, json.loads(out.getvalue())

    def test_one_provider_answer_is_enough(self):
        def fake(provider, *a, **k):
            if provider == "tavily":
                found = research.from_tavily(TAVILY)
                for item in found:
                    item["provider"] = provider
                return found, []
            raise research.Unavailable("no key")

        with mock.patch.object(research, "search_provider", fake):
            code, document = self.run_main(["web-research", "search", "nix flake", "--provider", "auto"])
        self.assertEqual(code, 0)
        self.assertEqual(document["providers"], ["tavily"])
        self.assertEqual(document["results"][0]["id"], "s1")
        self.assertEqual(len(document["warnings"]), 2)

    def test_no_provider_answer_exits_one(self):
        with mock.patch.object(research, "search_provider", side_effect=research.Unavailable("down")):
            code, document = self.run_main(["web-research", "search", "x"])
        self.assertEqual(code, 1)
        self.assertEqual(document["count"], 0)
        self.assertEqual(len(document["warnings"]), 3)


if __name__ == "__main__":
    unittest.main()
