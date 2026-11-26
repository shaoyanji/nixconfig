#!/usr/bin/env python3
"""Fixture for scripts/task/inventory-sync.py.

The mapping is the contract: `source=inventory.toml` and
`source_key=host/<name>` are what the service's own
`POST /api/import/inventory-toml` writes, so a sync must produce the same
identity or every host gets filed twice.
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
SPEC = importlib.util.spec_from_file_location("inventory_sync", ROOT / "scripts" / "task" / "inventory-sync.py")
sync = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sync)

DELPHI = {
    "hostname": "delphi",
    "kind": "nixos",
    "arch": "x86_64-linux",
    "status": "active",
    "status_detail": "The coordination host.",
    "role": "coordination",
    "hardware": {
        "model": "Beelink SER5",
        "cpu": "AMD Ryzen 7 5800H",
        "gpu": "",
        "ram": "11 GiB",
        "storage_type": "NVMe (/dev/sda2)",
        "storage_layout": "single btrfs pool",
        "display": "",
        "battery": "",
    },
    "network": {"tailscale_hostname": "delphi", "lan_ip": "10.0.0.5", "ssh_alias": "delphi"},
    "software": {"key_services": ["nginx :443", "postgres"], "traits": ["server", "amd"]},
    "notes": ["Runs the tailnet exit node."],
}

ACE = {
    "hostname": "",
    "kind": "nixos",
    "arch": "x86_64-linux",
    "status": "preserved",
    "hardware": {"model": "Desktop Workstation"},
    "network": {"ssh_alias": "aceofspades"},
    "software": {},
}

HOSTS = {"delphi": DELPHI, "aceofspades": ACE}


class MappingTest(unittest.TestCase):
    def setUp(self):
        self.item = sync.host_item("delphi", DELPHI)

    def test_identity_matches_the_service_import(self):
        self.assertEqual(self.item["source"], "inventory.toml")
        self.assertEqual(self.item["source_key"], "host/delphi")

    def test_name_and_category(self):
        self.assertEqual(self.item["name"], "delphi")
        self.assertEqual(self.item["category"], "fleet-host")

    def test_location_names_the_tailnet_and_lan(self):
        self.assertEqual(self.item["location"], "tailnet:delphi / lan:10.0.0.5")

    def test_hardware_goes_to_notes(self):
        self.assertIn("Hardware: AMD Ryzen 7 5800H; 11 GiB; NVMe (/dev/sda2)", self.item["notes"])
        self.assertIn("Storage layout: single btrfs pool", self.item["notes"])
        self.assertIn("Services: nginx :443; postgres", self.item["notes"])
        self.assertIn("Runs the tailnet exit node.", self.item["notes"])

    def test_tags_are_fleet_facts_then_traits(self):
        self.assertEqual(self.item["tags"], ["fleet", "active", "nixos", "x86_64-linux", "server", "amd"])

    def test_manufacturer_is_the_first_model_word(self):
        self.assertEqual(self.item["manufacturer"], "Beelink")
        self.assertEqual(self.item["model"], "Beelink SER5")

    def test_a_single_word_model_has_no_manufacturer(self):
        # `Desktop Workstation` is two words and yields `Desktop`; a model with
        # nothing before the name is the case with no manufacturer in it.
        self.assertEqual(sync.host_item("x", {"hostname": "x", "hardware": {"model": "MacMini"}})["manufacturer"], "")
        self.assertEqual(sync.host_item("aceofspades", ACE)["manufacturer"], "Desktop")

    def test_a_host_without_a_hostname_takes_its_key(self):
        self.assertEqual(sync.host_item("aceofspades", ACE)["name"], "aceofspades")

    def test_preserved_hosts_are_not_archived(self):
        self.assertFalse(sync.host_item("aceofspades", ACE)["archived"])
        self.assertTrue(sync.host_item("old", {**ACE, "status": "retired"})["archived"])

    def test_empty_hardware_makes_no_notes(self):
        item = sync.host_item("bare", {"hostname": "bare", "hardware": {}, "network": {}})
        self.assertEqual(item["notes"], "")
        self.assertEqual(item["location"], "fleet")


class BuildTest(unittest.TestCase):
    def test_hosts_are_sorted_by_key(self):
        items, _ = sync.build_items(HOSTS)
        self.assertEqual([i["source_key"] for i in items], ["host/aceofspades", "host/delphi"])

    def test_only_filters_by_key_or_hostname(self):
        items, _ = sync.build_items(HOSTS, only=["delphi"])
        self.assertEqual(len(items), 1)
        items, _ = sync.build_items(HOSTS, only=["aceofspades"])
        self.assertEqual(len(items), 1)

    def test_a_non_host_record_is_skipped_and_named(self):
        items, warnings = sync.build_items({"delphi": DELPHI, "junk": "nope"})
        self.assertEqual(len(items), 1)
        self.assertIn("not a host record", warnings[0])


class LoadTest(unittest.TestCase):
    def test_a_whole_inventory_document_uses_its_hosts_table(self):
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            json.dump({"hosts": HOSTS, "version": 1}, handle)
            path = handle.name
        self.assertEqual(sorted(sync.load_hosts(path=path)), ["aceofspades", "delphi"])

    def test_eval_reads_the_flake_attr(self):
        done = mock.Mock(returncode=0, stdout=json.dumps(HOSTS), stderr="")
        with mock.patch.object(sync.subprocess, "run", return_value=done) as run:
            hosts = sync.load_hosts(evaluate=True)
        self.assertEqual(run.call_args[0][0], ["nix", "eval", "--json", ".#inventory.hosts"])
        self.assertEqual(len(hosts), 2)

    def test_a_failed_eval_is_an_error_not_an_empty_fleet(self):
        done = mock.Mock(returncode=1, stdout="", stderr="error: attribute missing")
        with mock.patch.object(sync.subprocess, "run", return_value=done):
            with self.assertRaises(sync.SyncError):
                sync.load_hosts(evaluate=True)


class RunTest(unittest.TestCase):
    def run_main(self, argv, payload=None):
        out, err = io.StringIO(), io.StringIO()
        stdin = io.StringIO(json.dumps(payload if payload is not None else HOSTS))
        with mock.patch.object(sys, "argv", argv), mock.patch.object(
            sys, "stdin", stdin
        ), contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = sync.main()
        return code, out.getvalue(), err.getvalue()

    def test_dry_run_posts_nothing(self):
        with mock.patch.object(sync, "post_item", side_effect=AssertionError("posted")):
            code, out, err = self.run_main(["inventory-sync", "--dry-run"])
        summary = json.loads(out)
        self.assertEqual(code, 0)
        self.assertTrue(summary["dry_run"])
        self.assertEqual(summary["items"], 2)
        self.assertEqual(summary["created"], 0)
        self.assertIn("would_post", err)

    def test_each_item_is_posted_and_counted(self):
        answers = iter([{"id": 1, "created": True}, {"id": 2, "created": False}])
        with mock.patch.object(sync, "post_item", side_effect=lambda *a, **k: next(answers)):
            code, out, _ = self.run_main(["inventory-sync", "--api", "http://x"])
        summary = json.loads(out)
        self.assertEqual(code, 0)
        self.assertEqual((summary["created"], summary["updated"]), (1, 1))

    def test_one_refusal_does_not_stop_the_others(self):
        calls = []

        def half_fail(_api, payload, **_kwargs):
            calls.append(payload["source_key"])
            if len(calls) == 1:
                raise sync.SyncError("400 bad")
            return {"id": 2, "created": True}

        with mock.patch.object(sync, "post_item", half_fail):
            code, out, _ = self.run_main(["inventory-sync", "--api", "http://x"])
        summary = json.loads(out)
        self.assertEqual(code, 1)
        self.assertEqual(len(summary["failed"]), 1)
        self.assertEqual(summary["created"], 1)

    def test_toon_format_uses_the_encoder(self):
        with mock.patch.object(sync.shutil, "which", return_value="/bin/toon"), mock.patch.object(
            sync.subprocess, "run", return_value=mock.Mock(stdout="run: inventory-sync\n")
        ), mock.patch.object(sync, "post_item", return_value={"created": True}):
            code, out, _ = self.run_main(["inventory-sync", "--dry-run", "--format", "toon"])
        self.assertEqual(code, 0)
        self.assertEqual(out.strip(), "run: inventory-sync")


if __name__ == "__main__":
    unittest.main()
