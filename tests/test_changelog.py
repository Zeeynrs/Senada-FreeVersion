"""Offline tests for senada.changelog (run: python -m unittest discover tests)."""

import unittest

from senada import __version__, changelog


class Changelog(unittest.TestCase):
    def test_every_version_says_the_same_in_both_languages(self):
        for e in changelog.CHANGELOG:
            for kind in ("new", "fixed"):
                self.assertEqual(len(e["en"].get(kind, [])), len(e["id"].get(kind, [])), (e["version"], kind))

    def test_the_running_release_is_listed(self):
        self.assertIn(__version__, [e["version"] for e in changelog.CHANGELOG])

    def test_unreleased_changes_only_when_asked(self):
        self.assertNotIn("next", [e["version"] for e in changelog.entries("en", include_next=False)])
        self.assertEqual(changelog.entries("id", include_next=True)[0]["version"], "next")

    def test_dates_in_the_language(self):
        self.assertEqual(changelog.format_date("2026-08-13", "en"), "13 August 2026")
        self.assertEqual(changelog.format_date("2026-08-13", "id"), "13 Agustus 2026")
        self.assertEqual(changelog.format_date("", "id"), "")


if __name__ == "__main__":
    unittest.main()
