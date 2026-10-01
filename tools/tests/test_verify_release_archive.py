from pathlib import Path
import importlib.util
import tempfile
import unittest
import zipfile


TOOL = Path(__file__).resolve().parents[1] / "verify_release_archive.py"
SPEC = importlib.util.spec_from_file_location("verify_release_archive", TOOL)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class ReleaseArchiveTests(unittest.TestCase):
    def test_valid_package_reports_payload_and_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            archive_path = Path(directory) / "release.zip"
            with zipfile.ZipFile(archive_path, "w") as archive:
                archive.writestr("VillainsAndVelvet.exe", b"MZrunner")
                archive.writestr("data.win", b"FORMgame")
            result = MODULE.validate_archive(archive_path)
            self.assertEqual(result["file_count"], 2)
            self.assertEqual(result["executables"], ["VillainsAndVelvet.exe"])
            self.assertEqual(result["game_data"], ["data.win"])
            self.assertEqual(len(result["sha256"]), 64)

    def test_missing_and_corrupt_archives_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaisesRegex(ValueError, "missing"):
                MODULE.validate_archive(root / "missing.zip")
            corrupt = root / "corrupt.zip"
            corrupt.write_bytes(b"not a zip")
            with self.assertRaisesRegex(ValueError, "not a readable ZIP"):
                MODULE.validate_archive(corrupt)

    def test_package_requires_executable_and_game_data(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            no_executable = root / "no-executable.zip"
            with zipfile.ZipFile(no_executable, "w") as archive:
                archive.writestr("data.win", b"FORMgame")
            with self.assertRaisesRegex(ValueError, "no Windows executable"):
                MODULE.validate_archive(no_executable)
            no_data = root / "no-data.zip"
            with zipfile.ZipFile(no_data, "w") as archive:
                archive.writestr("VillainsAndVelvet.exe", b"MZrunner")
            with self.assertRaisesRegex(ValueError, "no GameMaker data file"):
                MODULE.validate_archive(no_data)


if __name__ == "__main__":
    unittest.main()
