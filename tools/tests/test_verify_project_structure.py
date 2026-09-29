"""Regression tests for the source-only project verifier."""

from pathlib import Path
import importlib.util
import unittest


TOOL = Path(__file__).resolve().parents[1] / "verify_project_structure.py"
SPEC = importlib.util.spec_from_file_location("verify_project_structure", TOOL)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class ProjectStructureTests(unittest.TestCase):
    def test_live_project_passes(self):
        self.assertEqual(MODULE.main(), 0)

    def test_global_function_names_are_unique(self):
        duplicates = {
            name: files
            for name, files in MODULE.script_functions().items()
            if len(files) > 1
        }
        self.assertEqual(duplicates, {})


if __name__ == "__main__":
    unittest.main()
