from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))

from package_windows_staging import package_staging


class PackageWindowsStagingTests(unittest.TestCase):
    def test_packages_release_payload_and_excludes_cache(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            staging = root / "staging"
            staging.mkdir()
            (staging / "VillainsAndVelvet.exe").write_bytes(b"exe")
            (staging / "data.win").write_bytes(b"data")
            (staging / "card_art").mkdir()
            (staging / "card_art" / "hero.png").write_bytes(b"png")
            (staging / "recover-cache").mkdir()
            (staging / "recover-cache" / "compiler.bin").write_bytes(b"cache")

            output = root / "release.zip"
            result = package_staging(staging, output)

            self.assertEqual(result["file_count"], 3)
            with zipfile.ZipFile(output) as archive:
                self.assertEqual(
                    sorted(archive.namelist()),
                    ["VillainsAndVelvet.exe", "card_art/hero.png", "data.win"],
                )

    def test_rejects_incomplete_payload(self):
        with tempfile.TemporaryDirectory() as temporary:
            staging = Path(temporary)
            (staging / "data.win").write_bytes(b"data")
            with self.assertRaisesRegex(ValueError, "VillainsAndVelvet.exe"):
                package_staging(staging, staging / "release.zip")


if __name__ == "__main__":
    unittest.main()
