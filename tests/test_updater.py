import unittest

try:
    from senada.updater import pick_setup_asset, version_tuple
except ImportError:  # PySide6 not installed
    version_tuple = None


@unittest.skipIf(version_tuple is None, "PySide6 tidak terpasang")
class ReleaseVersionTest(unittest.TestCase):
    def test_version_tuple(self):
        self.assertEqual(version_tuple("v1.2.10"), (1, 2, 10))
        self.assertEqual(version_tuple("1.0.0"), (1, 0, 0))
        self.assertEqual(version_tuple("Senada v2"), (2,))

    def test_newer_versions_compare_numerically(self):
        self.assertGreater(version_tuple("v1.10.0"), version_tuple("1.9.9"))
        self.assertGreater(version_tuple("v1.0.1"), version_tuple("1.0.0"))
        self.assertFalse(version_tuple("v1.0.0") > version_tuple("1.0.0"))

    def test_pick_setup_asset(self):
        assets = [{"name": "Source code.zip"}, {"name": "Senada-Setup-1.2.0.exe"}, {"name": "notes.txt"}]
        self.assertEqual(pick_setup_asset(assets)["name"], "Senada-Setup-1.2.0.exe")
        self.assertIsNone(pick_setup_asset([{"name": "Senada-Setup-1.2.0.exe.sig"}]))
        self.assertIsNone(pick_setup_asset([]))


if __name__ == "__main__":
    unittest.main()
