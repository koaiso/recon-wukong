import pathlib
import subprocess
import sys
import unittest


SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "tools" / "scope.py"


def run_filter(action, target, data=""):
    return subprocess.run(
        [sys.executable, str(SCRIPT), action, target],
        input=data, text=True, capture_output=True,
    )


class ScopeTest(unittest.TestCase):
    def test_rejects_url_wildcard_and_bad_label(self):
        for target in ("https://example.com", "*.example.com", "-x.example.com"):
            with self.subTest(target=target):
                self.assertNotEqual(run_filter("validate", target).returncode, 0)

    def test_subdomain_boundary(self):
        data = "example.com\na.example.com\nevil-example.com\na.example.com.evil.org\n"
        result = run_filter("hosts", "example.com", data)
        self.assertEqual(result.stdout.splitlines(), ["example.com", "a.example.com"])

    def test_url_boundary_credentials_and_fragment(self):
        data = ("https://a.example.com/x?q=1#fragment\n"
                "https://example.com.evil.org/x?q=2\n"
                "https://example.com@evil.org/x\n"
                "https://evil.org@example.com/private\n"
                "javascript://example.com/x\n")
        result = run_filter("urls", "example.com", data)
        self.assertEqual(result.stdout, "https://a.example.com/x?q=1\n")

    def test_non_200_live_and_query_keys(self):
        live = run_filter("live", "example.com", "https://a.example.com/ [403] [Forbidden]\n")
        self.assertEqual(live.stdout, "https://a.example.com/\n")
        urls = "https://a.example.com/api/v1?foo=1&foo=2&bar=\n"
        self.assertEqual(run_filter("params", "example.com", urls).stdout, urls)
        self.assertEqual(run_filter("keys", "example.com", urls).stdout, "2\tfoo\n1\tbar\n")


if __name__ == "__main__":
    unittest.main()
