"""The mount prober's verdicts: what counts as answering, and what does not."""

import io
import importlib.util
import json
import tempfile
import unittest
import urllib.error
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    "endpoints_smoke", ROOT / "scripts" / "task" / "endpoints-smoke.py"
)
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)


class FakeResponse:
    def __init__(self, status):
        self.status = status

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


def opener(status=None, error=None):
    def open_url(request, timeout=None):
        if error is not None:
            raise error
        return FakeResponse(status)

    return open_url


class MountTest(unittest.TestCase):
    def test_a_200_answers(self):
        ok, status, detail = smoke.check_mount("https://h:1/", 5, None, opener(200))
        self.assertTrue(ok)
        self.assertEqual(status, 200)
        self.assertIn("200", detail)

    def test_a_502_is_the_broken_mount_this_exists_for(self):
        ok, status, detail = smoke.check_mount("https://h:1/", 5, None, opener(502))
        self.assertFalse(ok)
        self.assertEqual(status, 502)
        self.assertIn("upstream failed", detail)

    def test_a_4xx_counts_as_answering(self):
        for code in (401, 403, 404):
            ok, status, _ = smoke.check_mount("https://h:1/", 5, None, opener(code))
            self.assertTrue(ok, code)
            self.assertEqual(status, code)

    def test_a_refused_connection_fails_with_the_reason(self):
        err = urllib.error.URLError(ConnectionRefusedError(111, "Connection refused"))
        ok, status, detail = smoke.check_mount("https://h:1/", 5, None, opener(error=err))
        self.assertFalse(ok)
        self.assertIsNone(status)
        self.assertIn("Connection refused", detail)

    def test_expect_narrows_what_passes(self):
        ok, status, detail = smoke.check_mount("https://h:1/", 5, {200}, opener(404))
        self.assertFalse(ok)
        self.assertIn("expected", detail)

    def test_expect_accepts_a_matching_code(self):
        ok, _, _ = smoke.check_mount("https://h:1/", 5, {200}, opener(200))
        self.assertTrue(ok)


class MainTest(unittest.TestCase):
    MOUNTS = {"appflow": {"port": 8463, "upstream": "http://127.0.0.1:8462"},
              "dsh": {"port": 8443, "upstream": "http://127.0.0.1:18900"}}

    def run_main(self, mounts, argv=(), status=200):
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            json.dump(mounts, handle)
            path = handle.name
        out, err = io.StringIO(), io.StringIO()
        import contextlib
        import sys

        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = smoke.main(["--in", path, *argv], opener=opener(status))
        return code, out.getvalue()

    def test_a_healthy_registry_exits_zero(self):
        code, out = self.run_main(self.MOUNTS)
        summary = json.loads(out)
        self.assertEqual(code, 0)
        self.assertTrue(summary["ok"])
        self.assertEqual(sorted(summary["mounts"]), ["appflow", "dsh"])

    def test_a_502_exits_one_and_names_the_mount(self):
        code, out = self.run_main(self.MOUNTS, status=502)
        summary = json.loads(out)
        self.assertEqual(code, 1)
        self.assertEqual(sorted(summary["failed"]), ["appflow", "dsh"])

    def test_an_empty_registry_is_refused_not_a_silent_pass(self):
        code, out = self.run_main({})
        self.assertEqual(code, 2)
        self.assertEqual(out, "")

    def test_toon_renders_nested_mounts(self):
        code, out = self.run_main(self.MOUNTS, argv=("--format", "toon"))
        self.assertEqual(code, 0)
        self.assertIn("mounts:", out)
        self.assertIn("ok: true", out)


if __name__ == "__main__":
    unittest.main()
