"""sync-record's --command must not replace the subcommand that main() dispatches on."""
import unittest

from tools.series import series


class SyncRecordCli(unittest.TestCase):
    def test_command_option_keeps_the_subcommand(self):
        args = series.parser().parse_args(["--series", "seriesb", "sync-record", "--command", "git town sync"])
        self.assertEqual(args.command, "sync-record")
        self.assertEqual(args.sync_command, "git town sync")

    def test_default_command(self):
        args = series.parser().parse_args(["--series", "seriesb", "sync-record"])
        self.assertEqual(args.command, "sync-record")
        self.assertEqual(args.sync_command, "git town sync --stack --detached --no-push")


if __name__ == "__main__":
    unittest.main()
