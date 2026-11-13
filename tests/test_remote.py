import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "system"))
import remote  # noqa: E402


class ActionForTest(unittest.TestCase):
    def test_ok_becomes_enter(self):
        self.assertEqual(remote.action_for("KEY_OK", 1), ["KEY_ENTER"])
        self.assertEqual(remote.action_for("KEY_SELECT", 1), ["KEY_ENTER"])

    def test_back_and_exit_go_back_in_browser(self):
        for key in ("KEY_BACK", "KEY_EXIT"):
            self.assertEqual(remote.action_for(key, 1), ["KEY_LEFTALT", "KEY_LEFT"])

    def test_home_returns_to_menu(self):
        self.assertEqual(remote.action_for("KEY_HOME", 1), remote.GO_HOME)
        self.assertEqual(remote.action_for("KEY_ROOT_MENU", 1), remote.GO_HOME)

    def test_release_is_ignored(self):
        self.assertIsNone(remote.action_for("KEY_OK", 0))

    def test_only_arrows_repeat_when_held(self):
        self.assertEqual(remote.action_for("KEY_DOWN", 2), ["KEY_DOWN"])
        self.assertIsNone(remote.action_for("KEY_OK", 2))
        self.assertIsNone(remote.action_for("KEY_HOME", 2))

    def test_unknown_key_is_ignored(self):
        self.assertIsNone(remote.action_for("KEY_RED", 1))

    def test_numbers_pass_through(self):
        self.assertEqual(remote.action_for("KEY_NUMERIC_7", 1), ["KEY_7"])


if __name__ == "__main__":
    unittest.main()
