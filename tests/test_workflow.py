import os
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]


class WorkflowTest(unittest.TestCase):
    def test_outputs_stay_in_scope_and_nuclei_is_opt_in(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = pathlib.Path(temporary)
            bin_dir = base / "bin"
            bin_dir.mkdir()
            commands = {
                "subfinder": "printf '%s\\n' a.example.com example.com.evil.org",
                "assetfinder": "printf '%s\\n' b.example.com evil-example.com",
                "httpx": "printf '%s\\n' 'https://a.example.com/ [403] [Forbidden]' 'http://example.com/ [301]' 'https://evil.org/ [200]'",
                "gau": "printf '%s\\n' 'https://a.example.com/api/v1?id=1' 'https://a.example.com/app.js' 'https://example.com.evil.org/?id=1' 'https://evil.org@example.com/private'",
                "katana": "printf '%s\\n' 'https://a.example.com/form?q=1' 'https://example.com.evil.org/private'",
                "nuclei": "touch \"$PWD/nuclei-was-run\"",
            }
            for name, body in commands.items():
                path = bin_dir / name
                path.write_text("#!/bin/sh\n" + body + "\n", encoding="utf-8")
                path.chmod(0o755)
            env = dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ["PATH"])
            output = base / "out"
            result = subprocess.run(
                ["bash", str(ROOT / "recon-wukong.sh"), "example.com", "--output", str(output)],
                cwd=base, env=env, capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((output / "hosts.txt").read_text().splitlines(),
                             ["a.example.com", "b.example.com", "example.com"])
            self.assertIn("https://a.example.com/", (output / "live-urls.txt").read_text())
            self.assertNotIn("evil.org", (output / "endpoints.txt").read_text())
            self.assertEqual((output / "params.txt").read_text(), "https://a.example.com/api/v1?id=1\n")
            self.assertEqual((output / "param-keys.tsv").read_text(), "1\tid\n")
            self.assertFalse((base / "nuclei-was-run").exists())
            crawled_output = base / "with-crawl"
            crawled = subprocess.run(
                ["bash", str(ROOT / "recon-wukong.sh"), "example.com", "--output", str(crawled_output), "--crawl"],
                cwd=base, env=env, capture_output=True, text=True,
            )
            self.assertEqual(crawled.returncode, 0, crawled.stderr)
            self.assertEqual((crawled_output / "crawled.txt").read_text(),
                             "https://a.example.com/form?q=1\n")
            self.assertIn("/form?q=1", (crawled_output / "endpoints.txt").read_text())


if __name__ == "__main__":
    unittest.main()
