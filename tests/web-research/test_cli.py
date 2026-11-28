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
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
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
# The v2 answer: `data` is an object of source arrays, and `warning` is a single
# optional string at the top level. v1 returned a flat `data` list instead.
FIRECRAWL = {
    "success": True,
    "data": {
        "web": [
            {
                "url": "https://news.ycombinator.com/item?id=32169454",
                "title": "About using Nix in my workflow",
                "description": "Flakes provide a consistent entry point.",
                "position": 1,
            }
        ]
    },
}

SEARCH_DOC = {
    "mode": "search",
    "query": "nix flake devshell",
    "providers": ["firecrawl", "tavily"],
    "count": 2,
    "results": [
        {
            "id": "s1",
            "title": "Nix flake: devShell [draft]",
            "url": "https://discourse.nixos.org/t/devshell/67351",
            "snippet": "mkShell in devShells.output",
        },
        {"id": "s2", "title": "", "url": "https://example.com/a(b)", "snippet": ""},
    ],
    "sources": [
        {
            "id": "s1",
            "url": "https://discourse.nixos.org/t/devshell/67351",
            "title": "Nix flake: devShell [draft]",
            "accessed": "2026-11-26T00:00:00Z",
        },
        {"id": "s2", "url": "https://example.com/a(b)", "title": "", "accessed": "2026-11-26T00:00:00Z"},
    ],
    "warnings": ["tavily: TAVILY_API_KEY is not set"],
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

    def test_firecrawl_reads_the_v2_web_array_and_a_flat_list(self):
        self.assertEqual(len(research.from_firecrawl(FIRECRAWL)), 1)
        self.assertEqual(research.from_firecrawl(FIRECRAWL)[0]["snippet"], "Flakes provide a consistent entry point.")
        flat = {"data": FIRECRAWL["data"]["web"]}
        self.assertEqual(len(research.from_firecrawl(flat)), 1)
        with_news = {"data": {"web": [], "news": FIRECRAWL["data"]["web"]}}
        self.assertEqual(len(research.from_firecrawl(with_news)), 1)

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

    def test_firecrawl_search_posts_to_v2(self):
        seen = {}

        def fake_post(url, body, **_kwargs):
            seen["url"] = url
            seen["body"] = body
            return FIRECRAWL

        with mock.patch.object(research, "post_json", fake_post):
            results, warnings = research.search_provider(
                "firecrawl", "nix flake", 4, {"FIRECRAWL_API_KEY": "k"}, 10
            )
        self.assertEqual(seen["url"], "https://api.firecrawl.dev/v2/search")
        self.assertEqual(seen["body"], {"query": "nix flake", "limit": 4})
        self.assertEqual(results[0]["provider"], "firecrawl")
        self.assertEqual(warnings, [])

    def test_a_firecrawl_warning_is_surfaced(self):
        payload = dict(FIRECRAWL, warning="the free tier rate-limits at 10 requests a minute")
        with mock.patch.object(research, "post_json", return_value=payload):
            _, warnings = research.search_provider(
                "firecrawl", "q", 3, {"FIRECRAWL_API_KEY": "k"}, 10
            )
        self.assertEqual(len(warnings), 1)
        self.assertIn("rate-limits", warnings[0])
        self.assertTrue(warnings[0].startswith("firecrawl: "))

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


class MarkdownTest(unittest.TestCase):
    def test_the_report_leads_with_the_query_and_counts(self):
        text = research.markdown_report(SEARCH_DOC)
        self.assertTrue(text.startswith("# nix flake devshell\n"))
        self.assertIn("2 results · providers: firecrawl, tavily", text)

    def test_every_hit_cites_an_id_that_is_a_link(self):
        text = research.markdown_report(SEARCH_DOC)
        self.assertIn("[s1](https://discourse.nixos.org/t/devshell/67351)", text)
        self.assertIn("[s2](https://example.com/a%28b%29)", text)

    def test_a_title_cannot_break_its_own_link(self):
        text = research.markdown_report(SEARCH_DOC)
        self.assertIn("[Nix flake: devShell \\[draft\\]](https://discourse.nixos.org/t/devshell/67351)", text)

    def test_sources_resolve_every_id_with_a_title_or_a_host(self):
        text = research.markdown_report(SEARCH_DOC)
        self.assertIn("## Sources", text)
        self.assertIn("- **[s1](https://discourse.nixos.org/t/devshell/67351)** — Nix flake: devShell \\[draft\\], accessed 2026-11-26T00:00:00Z", text)
        self.assertIn("- **[s2](https://example.com/a%28b%29)** — example.com", text)

    def test_a_snippet_loses_its_fences_and_extra_lines(self):
        text = research.md_snippet("`# flake.nix`\n\n\\[ inputs \\]\n" + "x" * 400)
        self.assertNotIn("`", text)
        self.assertNotIn("\n", text)
        self.assertLessEqual(len(text), 201)
        self.assertTrue(text.endswith("…"))

    def test_warnings_are_part_of_the_report(self):
        self.assertIn("_Warnings_", research.markdown_report(SEARCH_DOC))
        self.assertIn("TAVILY_API_KEY is not set", research.markdown_report(SEARCH_DOC))

    def test_an_empty_answer_still_says_so(self):
        empty = dict(SEARCH_DOC, count=0, results=[], sources=[], warnings=[])
        text = research.markdown_report(empty)
        self.assertIn("No page was found", text)
        self.assertIn("## Sources", text)

    def test_extract_keeps_the_page_body_below_its_citation(self):
        document = {
            "mode": "extract",
            "count": 1,
            "results": [
                {
                    "id": "s1",
                    "url": "https://nixos.org/manual/nix/stable/",
                    "title": "Nix manual",
                    "provider": "firecrawl",
                    "chars": 42,
                    "markdown": "# Nix manual\n\n`nix develop` opens a devshell.",
                }
            ],
            "sources": [
                {"id": "s1", "url": "https://nixos.org/manual/nix/stable/", "title": "Nix manual", "accessed": "T"}
            ],
            "warnings": [],
        }
        text = research.markdown_report(document)
        self.assertIn("## [Nix manual](https://nixos.org/manual/nix/stable/) [s1](https://nixos.org/manual/nix/stable/)", text)
        self.assertIn("`nix develop` opens a devshell.", text)
        self.assertIn("_42 chars via firecrawl_", text)

    def test_health_marks_each_page_and_names_the_problem(self):
        document = {
            "mode": "health",
            "via": "clanker",
            "count": 2,
            "healthy": 1,
            "pages": [
                {"url": "https://a.example", "ok": True, "title": "A", "text_chars": 900, "links": 12, "http_status": 200, "problems": []},
                {"url": "https://b.example", "ok": False, "title": "", "text_chars": 20, "links": 0, "http_status": 403, "problems": ["http 403", "no title"]},
            ],
            "warnings": [],
        }
        text = research.markdown_report(document)
        self.assertIn("1 of 2 rendered (via clanker)", text)
        self.assertIn("**ok** [A](https://a.example)", text)
        self.assertIn("**FAIL** [b.example](https://b.example)", text)
        self.assertIn("http 403; no title", text)

    def test_emit_prints_markdown_without_a_json_fence(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            research.emit(SEARCH_DOC, "markdown")
        self.assertTrue(out.getvalue().startswith("# nix flake devshell"))


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

    def test_the_cli_can_answer_in_markdown(self):
        def fake(provider, *a, **k):
            found = research.from_tavily(TAVILY)
            for item in found:
                item["provider"] = provider
            return found, []

        out = io.StringIO()
        with mock.patch.object(
            sys, "argv", ["web-research", "search", "nix flake devshell", "--provider", "tavily", "--format", "markdown"]
        ), mock.patch.object(research, "load_keys", return_value={"TAVILY_API_KEY": "k"}), mock.patch.object(
            research, "search_provider", fake
        ), contextlib.redirect_stdout(out):
            code = research.main()
        text = out.getvalue()
        self.assertEqual(code, 0)
        self.assertTrue(text.startswith("# nix flake devshell"))
        self.assertIn("[s1](https://discourse.nixos.org/t/devshell/67351)", text)
        self.assertIn("## Sources", text)

    def test_no_provider_answer_exits_one(self):
        with mock.patch.object(research, "search_provider", side_effect=research.Unavailable("down")):
            code, document = self.run_main(["web-research", "search", "x"])
        self.assertEqual(code, 1)
        self.assertEqual(document["count"], 0)
        self.assertEqual(len(document["warnings"]), 3)


class VaultStub:
    """link-vault's `POST /api/links` over a real socket, canned by status code.

    Statuses are consumed in order: 201 is a new link, 200 is the upsert of one
    the vault already holds, and anything else is a refusal with a JSON reason.
    """

    def __init__(self, statuses=None, extractions=None):
        self.requests = []
        self.statuses = list(statuses or [])
        self.extractions = list(extractions or [])
        stub = self

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                length = int(self.headers.get("content-length") or 0)
                body = json.loads(self.rfile.read(length) or b"{}")
                stub.requests.append(
                    {
                        "path": self.path,
                        "body": body,
                        "auth": self.headers.get("Authorization"),
                    }
                )
                status = stub.statuses.pop(0) if stub.statuses else 201
                if status >= 400:
                    payload = {"error": "the vault refused this one"}
                else:
                    payload = {"link": {"id": len(stub.requests), "url": body.get("url")}, "created": status == 201}
                    if stub.extractions:
                        payload["extraction"] = stub.extractions.pop(0)
                    elif body.get("extract"):
                        payload["extraction"] = {"requested": True, "ok": True, "provider": "firecrawl"}
                data = json.dumps(payload).encode()
                self.send_response(status)
                self.send_header("content-type", "application/json")
                self.send_header("content-length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)

            def log_message(self, *args):
                pass

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.base = f"http://127.0.0.1:{self.server.server_address[1]}"

    def close(self):
        self.server.shutdown()
        self.server.server_close()


def one_hit(*_args, **_kwargs):
    found = research.from_tavily(TAVILY)
    for item in found:
        item["provider"] = "tavily"
    return found, []


class VaultPushTest(unittest.TestCase):
    def setUp(self):
        self.vault = VaultStub()
        self.addCleanup(self.vault.close)

    def search(self, argv, hits=None):
        args = research.build_parser().parse_args(argv)
        with mock.patch.object(research, "search_provider", side_effect=hits or one_hit):
            return research.do_search(args, {"TAVILY_API_KEY": "k"})

    def test_one_hit_is_one_post_with_the_research_fields(self):
        document = self.search(
            ["search", "nix flake", "--provider", "tavily", "--link-vault", self.vault.base]
        )
        self.assertEqual(len(self.vault.requests), 1)
        request = self.vault.requests[0]
        self.assertEqual(request["path"], "/api/links")
        self.assertEqual(
            request["body"],
            {
                "url": "https://discourse.nixos.org/t/devshell/67351",
                "title": "Nix flake: devShell with python modules",
                "description": document["results"][0]["snippet"],
                "source": "web-research",
            },
        )
        self.assertEqual(document["link_vault"]["pushed"], 1)
        self.assertEqual(document["link_vault"]["skipped"], 0)
        self.assertEqual(document["link_vault"]["failed"], 0)

    def test_a_page_the_vault_already_holds_is_a_skip_not_a_failure(self):
        self.vault.statuses = [201, 200]
        two = [
            {"title": "A", "url": "https://a.example/x", "snippet": "a", "provider": "tavily"},
            {"title": "B", "url": "https://b.example/y", "snippet": "b", "provider": "tavily"},
        ]
        document = self.search(
            ["search", "q", "--provider", "tavily", "--link-vault", self.vault.base],
            hits=lambda *a, **k: ([dict(item) for item in two], []),
        )
        self.assertEqual(len(self.vault.requests), 2)
        self.assertEqual([self.vault.requests[0]["body"]["url"], self.vault.requests[1]["body"]["url"]], ["https://a.example/x", "https://b.example/y"])
        self.assertEqual(document["link_vault"]["pushed"], 1)
        self.assertEqual(document["link_vault"]["skipped"], 1)
        self.assertEqual(document["link_vault"]["failed"], 0)

    def test_collection_and_tags_are_forwarded_deduped(self):
        self.search(
            [
                "search",
                "q",
                "--provider",
                "tavily",
                "--link-vault",
                self.vault.base,
                "--collection",
                "reading",
                "--tags",
                " nix, flake ,nix,,",
            ]
        )
        body = self.vault.requests[0]["body"]
        self.assertEqual(body["collection"], "reading")
        self.assertEqual(body["tags"], ["nix", "flake"])

    def test_no_flag_means_no_push_and_no_key(self):
        document = self.search(["search", "q", "--provider", "tavily"])
        self.assertNotIn("link_vault", document)
        self.assertEqual(self.vault.requests, [])

    def test_a_refusal_is_counted_with_the_vault_reason(self):
        self.vault.statuses = [500]
        document = self.search(
            ["search", "q", "--provider", "tavily", "--link-vault", self.vault.base]
        )
        self.assertEqual(document["link_vault"]["failed"], 1)
        self.assertEqual(document["link_vault"]["pushed"], 0)
        self.assertIn("HTTP 500", document["link_vault"]["errors"][0]["error"])
        self.assertIn("the vault refused this one", document["link_vault"]["errors"][0]["error"])

    def test_an_unreachable_vault_fails_each_hit(self):
        document = self.search(["search", "q", "--provider", "tavily", "--link-vault", "http://127.0.0.1:9"])
        self.assertEqual(document["link_vault"]["failed"], 1)
        self.assertIn("unreachable", document["link_vault"]["errors"][0]["error"])

    def test_the_token_travels_as_a_bearer(self):
        self.search(
            ["search", "q", "--provider", "tavily", "--link-vault", self.vault.base, "--link-vault-token", "t0k"]
        )
        self.assertEqual(self.vault.requests[0]["auth"], "Bearer t0k")

    def test_a_relative_base_is_refused_before_any_request(self):
        with self.assertRaises(ValueError) as caught:
            research.absolute_base("localhost:8106")
        self.assertIn("absolute http(s) URL", str(caught.exception))
        with mock.patch.object(sys, "argv", ["web-research", "search", "q", "--link-vault", "localhost:8106"]), contextlib.redirect_stdout(
            io.StringIO()
        ), contextlib.redirect_stderr(io.StringIO()) as err:
            self.assertEqual(research.main(), 2)
        self.assertIn("absolute http(s) URL", err.getvalue())
        self.assertEqual(self.vault.requests, [])

    def test_a_failed_push_sets_the_exit_code(self):
        self.vault.statuses = [500]
        out = io.StringIO()
        with mock.patch.object(
            sys, "argv", ["web-research", "search", "q", "--provider", "tavily", "--link-vault", self.vault.base]
        ), mock.patch.object(research, "load_keys", return_value={"TAVILY_API_KEY": "k"}), mock.patch.object(
            research, "search_provider", side_effect=one_hit
        ), contextlib.redirect_stdout(out):
            code = research.main()
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(out.getvalue())["link_vault"]["failed"], 1)

    def test_markdown_names_the_vault_and_its_counts(self):
        document = self.search(["search", "q", "--provider", "tavily", "--link-vault", self.vault.base])
        text = research.markdown_report(document)
        self.assertIn("_Link vault http://127.0.0.1:", text)
        self.assertIn("1 pushed, 0 skipped, 0 failed, 0 extracted, 0 extract-failed_", text)

    def test_markdown_lists_what_the_vault_refused(self):
        self.vault.statuses = [400]
        document = self.search(["search", "q", "--provider", "tavily", "--link-vault", self.vault.base])
        text = research.markdown_report(document)
        self.assertIn("0 pushed, 0 skipped, 1 failed, 0 extracted, 0 extract-failed_", text)
        self.assertIn("https://discourse.nixos.org/t/devshell/67351: HTTP 400", text)


class ExtractOnPushTest(unittest.TestCase):
    def setUp(self):
        self.vault = VaultStub()
        self.addCleanup(self.vault.close)

    def search(self, argv, hits=None):
        args = research.build_parser().parse_args(argv)
        with mock.patch.object(research, "search_provider", side_effect=hits or one_hit):
            return research.do_search(args, {"TAVILY_API_KEY": "k"})

    def two_hits(self, *_args, **_kwargs):
        return (
            [
                {"title": "A", "url": "https://a.example/x", "snippet": "a", "provider": "tavily"},
                {"title": "B", "url": "https://b.example/y", "snippet": "b", "provider": "tavily"},
            ],
            [],
        )

    def test_extract_on_push_rides_the_same_request(self):
        document = self.search(
            ["search", "q", "--provider", "tavily", "--link-vault", self.vault.base, "--extract-on-push"]
        )
        self.assertEqual(len(self.vault.requests), 1)
        self.assertIs(self.vault.requests[0]["body"]["extract"], True)
        self.assertNotIn("provider", self.vault.requests[0]["body"])
        self.assertEqual(document["link_vault"]["pushed"], 1)
        self.assertEqual(document["link_vault"]["extracted"], 1)
        self.assertEqual(document["link_vault"]["extract_failed"], 0)

    def test_the_extraction_provider_is_forwarded(self):
        self.search(
            [
                "search",
                "q",
                "--provider",
                "tavily",
                "--link-vault",
                self.vault.base,
                "--extract-on-push",
                "--extract-provider",
                "tavily",
            ]
        )
        self.assertEqual(self.vault.requests[0]["body"]["provider"], "tavily")

    def test_without_the_flag_the_body_carries_no_extract_key(self):
        self.search(["search", "q", "--provider", "tavily", "--link-vault", self.vault.base])
        self.assertNotIn("extract", self.vault.requests[0]["body"])
        self.assertNotIn("provider", self.vault.requests[0]["body"])

    def test_a_page_text_that_refuses_keeps_its_link_and_is_counted_apart(self):
        self.vault.extractions = [
            {"requested": True, "ok": False, "error": "firecrawl: 403 from the origin"},
            {"requested": True, "ok": True, "provider": "firecrawl"},
        ]
        document = self.search(
            ["search", "q", "--provider", "tavily", "--link-vault", self.vault.base, "--extract-on-push"],
            hits=self.two_hits,
        )
        counts = document["link_vault"]
        self.assertEqual((counts["pushed"], counts["failed"]), (2, 0))
        self.assertEqual((counts["extracted"], counts["extract_failed"]), (1, 1))
        self.assertEqual(len(counts["errors"]), 1)
        self.assertEqual(counts["errors"][0]["url"], "https://a.example/x")
        self.assertIn("extract: firecrawl: 403 from the origin", counts["errors"][0]["error"])

    def test_an_upsert_still_counts_as_a_skip_while_it_extracts(self):
        self.vault.statuses = [200]
        document = self.search(
            ["search", "q", "--provider", "tavily", "--link-vault", self.vault.base, "--extract-on-push"]
        )
        self.assertEqual(document["link_vault"]["skipped"], 1)
        self.assertEqual(document["link_vault"]["pushed"], 0)
        self.assertEqual(document["link_vault"]["extracted"], 1)

    def test_an_answer_without_an_extraction_is_a_named_failure(self):
        self.vault.extractions = [{"requested": True}]
        document = self.search(
            ["search", "q", "--provider", "tavily", "--link-vault", self.vault.base, "--extract-on-push"]
        )
        self.assertEqual(document["link_vault"]["extract_failed"], 1)
        self.assertIn("no extraction", document["link_vault"]["errors"][0]["error"])

    def test_extract_without_a_vault_is_refused(self):
        with mock.patch.object(sys, "argv", ["web-research", "search", "q", "--extract-on-push"]), contextlib.redirect_stdout(
            io.StringIO()
        ), contextlib.redirect_stderr(io.StringIO()) as err:
            self.assertEqual(research.main(), 2)
        self.assertIn("need --link-vault", err.getvalue())
        self.assertEqual(self.vault.requests, [])

    def test_markdown_shows_extraction_counts(self):
        self.vault.extractions = [{"requested": True, "ok": False, "error": "tavily: 429"}]
        document = self.search(
            ["search", "q", "--provider", "tavily", "--link-vault", self.vault.base, "--extract-on-push"]
        )
        text = research.markdown_report(document)
        self.assertIn("1 pushed, 0 skipped, 0 failed, 0 extracted, 1 extract-failed_", text)
        self.assertIn("extract: tavily: 429", text)


if __name__ == "__main__":
    unittest.main()
