import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "system"))
import build_sites  # noqa: E402

REPO = os.path.join(os.path.dirname(__file__), "..")


def write(tmp, content):
    path = os.path.join(tmp, "sites.json")
    with open(path, "w", encoding="utf-8") as f:
        f.write(content if isinstance(content, str) else json.dumps(content))
    return path


class LoadSitesTest(unittest.TestCase):
    def test_shipped_config_is_valid(self):
        sites, warnings = build_sites.load_sites(os.path.join(REPO, "config", "sites.json"))
        self.assertEqual(warnings, [])
        self.assertGreater(len(sites), 0)

    def test_skips_bad_entries_and_keeps_good_ones(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = write(tmp, {"sites": [
                {"name": "Good", "url": "https://example.com"},
                {"name": "No URL"},
                {"name": "Bad scheme", "url": "javascript:alert(1)"},
                "not an object",
            ]})
            sites, warnings = build_sites.load_sites(path)
        self.assertEqual([s["name"] for s in sites], ["Good"])
        self.assertEqual(len(warnings), 3)

    def test_invalid_json_reports_line(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = write(tmp, '{"sites": [ {"name": "x",} ]}')
            sites, warnings = build_sites.load_sites(path)
        self.assertEqual(sites, [])
        self.assertIn("line 1", warnings[0])

    def test_missing_file(self):
        sites, warnings = build_sites.load_sites("/nonexistent/sites.json")
        self.assertEqual(sites, [])
        self.assertIn("not found", warnings[0])

    def test_render_escapes_script_close(self):
        out = build_sites.render([{"name": "</script>", "url": "https://x", "category": "", "note": ""}], [])
        self.assertNotIn("</script>", out)


if __name__ == "__main__":
    unittest.main()
