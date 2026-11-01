import os
import tempfile
import unittest

from tools.series import normalise
from tools.series.tests.fixtures import A1, git, make_history_repo


@unittest.skipUnless(os.path.exists(normalise.CLANG_FORMAT), "clang-format 22 venv missing (T002)")
class NormaliseTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.fx = make_history_repo(cls.tmp.name)
        cls.cache = os.path.join(cls.tmp.name, "cache.json")

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def norm(self, tree):
        return normalise.normalise_tree(self.fx["game"], tree, self.fx["u0"], cache_path=self.cache)

    def test_formats_sources_with_the_given_style(self):
        out = self.norm(f"{self.fx['u0']}^{{tree}}")
        self.assertEqual(git(self.fx["game"], "show", f"{out}:src/a.m") + "\n", A1)

    def test_idempotent(self):
        once = self.norm(f"{self.fx['u0']}^{{tree}}")
        self.assertEqual(self.norm(once), once)

    def test_non_sources_untouched(self):
        src = f"{self.fx['u0']}^{{tree}}"
        out = self.norm(src)
        for path in ("README", ".clang-format"):
            self.assertEqual(git(self.fx["game"], "rev-parse", f"{out}:{path}"),
                             git(self.fx["game"], "rev-parse", f"{src}:{path}"))

    def test_test_sources_are_not_formatted(self):
        self.assertTrue(normalise.is_source("src/Core/a.mm"))
        self.assertFalse(normalise.is_source("tests/unit/oofnd/test_objc_ref.mm"))
        self.assertFalse(normalise.is_source("tests/unit/core/test_AI.cpp"))

    def test_cache_is_written(self):
        self.norm(f"{self.fx['u2']}^{{tree}}")
        self.assertTrue(os.path.exists(self.cache))


if __name__ == "__main__":
    unittest.main()
