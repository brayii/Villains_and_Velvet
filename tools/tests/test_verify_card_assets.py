from pathlib import Path
import importlib.util
import tempfile
import unittest


TOOL = Path(__file__).resolve().parents[1] / "verify_card_assets.py"
SPEC = importlib.util.spec_from_file_location("verify_card_assets", TOOL)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class CardAssetTests(unittest.TestCase):
    def test_header_only_png_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "stub.png"
            path.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\x0dIHDR" + b"\x00" * 8)
            with self.assertRaises(ValueError):
                MODULE.png_dimensions(path)


if __name__ == "__main__":
    unittest.main()
