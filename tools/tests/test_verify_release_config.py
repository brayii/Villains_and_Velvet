from pathlib import Path
import importlib.util
import unittest


TOOL = Path(__file__).resolve().parents[1] / "verify_release_config.py"
SPEC = importlib.util.spec_from_file_location("verify_release_config", TOOL)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class ReleaseConfigTests(unittest.TestCase):
    def test_current_project_release_configuration_passes(self):
        errors = MODULE.verify_release_config()
        self.assertEqual(errors, [])

    def test_all_sound_resources_are_registered(self):
        errors = MODULE.verify_release_config()
        self.assertFalse(any("Sound" in error or "audio Included" in error for error in errors))

    def test_gitignore_negation_is_honored(self):
        self.assertFalse(MODULE.gitignore_protects("*.jks\n!release-signing.jks\n", "release-signing.jks"))
        self.assertTrue(MODULE.gitignore_protects("*.jks\n", "release-signing.jks"))


if __name__ == "__main__":
    unittest.main()
