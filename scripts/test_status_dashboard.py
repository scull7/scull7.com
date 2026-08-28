#!/usr/bin/env python3
"""Unit tests for status-dashboard calculations. No pinto, no I/O."""

from __future__ import annotations

import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path

dash = SourceFileLoader(
    "status_dashboard",
    str(Path(__file__).resolve().parent / "status-dashboard"),
).load_module()


class ClassifyTests(unittest.TestCase):
    def test_observed_pinto_words(self) -> None:
        self.assertEqual(dash.classify("done"), dash.DONE)
        self.assertEqual(dash.classify("in-progress"), dash.ACTIVE)
        self.assertEqual(dash.classify("review"), dash.ACTIVE)
        self.assertEqual(dash.classify("todo"), dash.TODO)

    def test_normalises_separators(self) -> None:
        self.assertEqual(dash.classify("In Progress"), dash.ACTIVE)
        self.assertEqual(dash.classify("in_progress"), dash.ACTIVE)


class BoardItemsTests(unittest.TestCase):
    RAW = [
        {"id": "T-8", "title": "Leave nathansculli.com retired at NXDOMAIN",
         "status": "in-progress"},
        {"id": "T-14", "title": "Extract reusable site framework", "status": "todo"},
        {"id": "T-1", "title": "Refresh resume.json", "status": "done"},
    ]

    def test_shapes_pinto_list_payload(self) -> None:
        items = dash.board_items(self.RAW)
        self.assertEqual([i["id"] for i in items], ["T-8", "T-14", "T-1"])
        self.assertEqual([i["state"] for i in items],
                         [dash.ACTIVE, dash.TODO, dash.DONE])

    def test_rejects_non_list_payload(self) -> None:
        with self.assertRaises(ValueError):
            dash.board_items({"tasks": self.RAW})


class TotalsTests(unittest.TestCase):
    def test_counts_board_only(self) -> None:
        board = dash.board_items([
            {"id": "T-1", "title": "a", "status": "done"},
            {"id": "T-2", "title": "b", "status": "done"},
            {"id": "T-8", "title": "c", "status": "in-progress"},
            {"id": "T-14", "title": "d", "status": "todo"},
            {"id": "T-25", "title": "e", "status": "todo"},
        ])
        t = dash.totals(board)
        self.assertEqual(t[dash.DONE], 2)
        self.assertEqual(t[dash.ACTIVE], 1)
        self.assertEqual(t[dash.TODO], 2)
        self.assertEqual(t["source"], "pinto list --json")

    def test_build_model_has_no_features_source(self) -> None:
        model = dash.build_model(
            pinto_raw=[{"id": "T-8", "title": "x", "status": "in-progress"}],
            progress_tail="",
            project="scull7.com",
            generated="test",
        )
        self.assertNotIn("phases", model)
        self.assertEqual(model["totals"]["source"], "pinto list --json")
        self.assertEqual(model["totals"][dash.ACTIVE], 1)


class ConfigTests(unittest.TestCase):
    def test_drops_features_file_from_merged_config(self) -> None:
        cfg = dash.load_config(Path("/tmp"), None)
        self.assertNotIn("features_file", cfg)
        self.assertEqual(cfg["board"]["command"], ["pinto", "list", "--json"])
        self.assertEqual(cfg.get("project") or "", "")


if __name__ == "__main__":
    unittest.main()
