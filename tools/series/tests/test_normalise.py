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

    def test_test_sources_get_the_rename_but_keep_their_layout(self):
        game = self.fx["game"]
        text = '#include "z.h"\n#include "a.h"\nint   oldName(void){return 1;}\n'
        blob = git(game, "hash-object", "-w", "--stdin", input_text=text)
        base = git(game, "rev-parse", f"{self.fx['u0']}^{{tree}}")
        # NUL-separated (-z): text-mode input on Windows would add a CR to every path
        tests_tree = git(game, "mktree", "-z", input_text=f"100644 blob {blob}\tt.cpp\0")
        top = "".join(line + "\0" for line in git(game, "ls-tree", base).splitlines())
        tree = git(game, "mktree", "-z", input_text=top + f"040000 tree {tests_tree}\ttests\0")
        out = normalise.normalise_tree(game, tree, self.fx["u0"], cache_path=self.cache,
                                       transform=lambda p, t: t.replace("oldName", "newName"), transform_id="t1")
        self.assertEqual(git(game, "show", f"{out}:tests/t.cpp") + "\n",
                         '#include "z.h"\n#include "a.h"\nint   newName(void){return 1;}\n')

    def test_cache_is_written(self):
        self.norm(f"{self.fx['u2']}^{{tree}}")
        self.assertTrue(os.path.exists(self.cache))


if __name__ == "__main__":
    unittest.main()
