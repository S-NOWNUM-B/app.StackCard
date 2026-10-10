"""Проверки нативного hook через настоящие Git commits в изолированных checkout."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SUBJECT = "fix(git): исправил проверку сообщений коммитов по фактическим файлам index"


def message(paths):
    return SUBJECT + "\n\n" + "\n".join("- " + path + ": добавил содержимое файла" for path in paths) + "\n"


class NativeHookTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="stackcard-git-hooks-")
        self.addCleanup(self.temporary.cleanup)
        self.repo = Path(self.temporary.name)
        self.env = os.environ.copy()
        # Тестовые Git не наследуют repository/index/editor overrides пользователя.
        for key in list(self.env):
            if key.startswith("GIT_") or key == "STACKCARD_COMMIT_MODE":
                del self.env[key]
        self.env["PYTHONDONTWRITEBYTECODE"] = "1"
        self.run_git("init", "--quiet", "--initial-branch=dev")
        self.run_git("config", "user.name", "Hook Test")
        self.run_git("config", "user.email", "hook@example.invalid")
        self.run_git("config", "commit.gpgsign", "false")
        self.run_git("config", "core.hooksPath", ".githooks")
        for source in (".githooks/commit-msg", "tools/git/validate_commit_message.py"):
            target = self.repo / source
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / source, target)
        (self.repo / ".githooks/commit-msg").chmod(0o755)
        self.message_path = self.repo / "candidate-message.txt"

    def run_git(self, *args, check=True, env=None):
        return subprocess.run(
            ["git", *args], cwd=self.repo, env=self.env if env is None else env,
            capture_output=True, text=True, check=check, timeout=20,
        )

    def stage(self, path, content="content\n"):
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        self.run_git("add", "--", path)

    def commit(self, text, *args, mode=None, env=None):
        self.message_path.write_text(text, encoding="utf-8")
        environment = dict(self.env if env is None else env)
        if mode is not None:
            environment["STACKCARD_COMMIT_MODE"] = mode
        return self.run_git("commit", *args, "-F", str(self.message_path), check=False, env=environment)

    def assert_commit(self, paths, *args, mode=None):
        result = self.commit(message(paths), *args, mode=mode)
        self.assertEqual(result.returncode, 0, result.stderr)
        saved = self.run_git("show", "-s", "--format=%B", "HEAD").stdout
        self.assertEqual(saved.rstrip(), message(paths).rstrip())
        files = self.run_git("diff-tree", "--root", "--no-renames", "--no-commit-id", "--name-only", "-z", "-r", "HEAD").stdout
        self.assertEqual(set(files.strip("\0").split("\0")), set(paths))

    def test_initial_commit_and_long_body(self):
        paths = ["files/" + str(index) + ".txt" for index in range(35)]
        for path in paths:
            self.stage(path)
        text = SUBJECT + "\n\n" + "\n".join("- " + path + ": " + ("описал изменение " * 12).rstrip() for path in paths) + "\n"
        self.assertGreater(len(text), 4000)
        result = self.commit(text)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.run_git("show", "-s", "--format=%B", "HEAD").stdout.rstrip(), text.rstrip())

    def test_invalid_messages_do_not_create_commit(self):
        self.stage("a.txt")
        self.stage("b.txt")
        invalid = [
            SUBJECT + "\n", message(["a.txt"]), message(["a.txt", "b.txt", "extra.txt"]),
            message(["a.txt", "b.txt", "a.txt"]),
            message(["a.txt", "b.txt"]).replace("- b.txt: добавил содержимое файла", "- b.txt: "),
            message(["a.txt", "b.txt"]).replace("исправил", "Исправил", 1),
        ]
        for text in invalid:
            with self.subTest(message=text):
                result = self.commit(text)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("StackCard commit-msg:", result.stderr)
                self.assertNotEqual(self.run_git("rev-parse", "--verify", "HEAD", check=False).returncode, 0)

    def test_rename_requires_old_and_new_paths(self):
        self.stage("old.txt")
        self.assert_commit(["old.txt"])
        self.run_git("mv", "old.txt", "new.txt")
        self.assertNotEqual(self.commit(message(["new.txt"])).returncode, 0)
        self.assert_commit(["old.txt", "new.txt"])

    def test_literal_paths_and_unstaged_file(self):
        paths = ["report", "report: данные v1.txt"]
        for path in paths:
            self.stage(path)
        (self.repo / "untracked.txt").write_text("untracked\n")
        self.assert_commit(paths)

    def test_initial_commit_excludes_intent_to_add(self):
        self.stage("a.txt")
        (self.repo / "b.txt").write_text("intent to add\n")
        self.run_git("add", "--intent-to-add", "b.txt")
        self.assertNotEqual(self.commit(message(["a.txt", "b.txt"])).returncode, 0)
        self.assert_commit(["a.txt"])

    def test_initial_amend_excludes_intent_to_add(self):
        self.stage("a.txt")
        self.assert_commit(["a.txt"])
        (self.repo / "b.txt").write_text("intent to add\n")
        self.run_git("add", "--intent-to-add", "b.txt")
        self.assertNotEqual(self.commit(message(["a.txt", "b.txt"]), "--amend", mode="amend").returncode, 0)
        self.assert_commit(["a.txt"], "--amend", mode="amend")

    def test_ordinary_commit_rejects_previous_commit_paths(self):
        self.stage("a.txt")
        self.assert_commit(["a.txt"])
        self.stage("b.txt")
        self.assertNotEqual(self.commit(message(["a.txt", "b.txt"])).returncode, 0)
        self.assert_commit(["b.txt"])

    def test_initial_amend_requires_explicit_mode(self):
        self.stage("a.txt")
        self.assert_commit(["a.txt"])
        before = self.run_git("rev-parse", "HEAD^{tree}").stdout
        self.assertNotEqual(self.commit(message(["a.txt"]), "--amend").returncode, 0)
        self.assert_commit(["a.txt"], "--amend", mode="amend")
        self.assertEqual(self.run_git("rev-parse", "HEAD^{tree}").stdout, before)

    def test_amend_with_staged_changes_keeps_original_files(self):
        self.stage("base.txt")
        self.assert_commit(["base.txt"])
        self.stage("a.txt")
        self.assert_commit(["a.txt"])
        self.stage("b.txt")
        self.assertNotEqual(self.commit(message(["b.txt"]), "--amend", mode="amend").returncode, 0)
        self.assert_commit(["a.txt", "b.txt"], "--amend", mode="amend")

    def test_amend_revert_removes_path_from_resulting_commit(self):
        self.stage("a.txt", "original\n")
        self.assert_commit(["a.txt"])
        self.stage("a.txt", "changed\n")
        self.stage("b.txt")
        self.assert_commit(["a.txt", "b.txt"])
        self.stage("a.txt", "original\n")
        self.assertNotEqual(self.commit(message(["a.txt", "b.txt"]), "--amend", mode="amend").returncode, 0)
        self.assert_commit(["b.txt"], "--amend", mode="amend")

    def test_partial_commit_uses_git_prospective_index(self):
        self.stage("a.txt")
        self.assert_commit(["a.txt"])
        self.stage("a.txt", "updated\n")
        self.stage("b.txt")
        self.assert_commit(["a.txt"], "--only", "a.txt")
        self.assertEqual(self.run_git("diff", "--cached", "--name-only").stdout.strip(), "b.txt")

    def test_invalid_mode_and_missing_head_amend_are_rejected(self):
        self.stage("a.txt")
        for mode in ("invalid", "amend"):
            with self.subTest(mode=mode):
                self.assertNotEqual(self.commit(message(["a.txt"]), mode=mode).returncode, 0)

    def test_editor_comments_are_removed_from_saved_message(self):
        self.stage("a.txt")
        self.run_git("config", "commit.cleanup", "verbatim")
        text = message(["a.txt"]) + "\n# Git editor help\n# Changes to be committed:\n"
        result = self.commit(text)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.run_git("show", "-s", "--format=%B", "HEAD").stdout.rstrip(), message(["a.txt"]).rstrip())

    def test_real_editor_commit_removes_git_status_comments(self):
        self.stage("a.txt")
        environment = dict(self.env, GIT_EDITOR="true")
        result = self.commit(message(["a.txt"]), "--edit", env=environment)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.run_git("show", "-s", "--format=%B", "HEAD").stdout.rstrip(), message(["a.txt"]).rstrip())

    def test_comment_prefix_cannot_strip_body_after_validation(self):
        self.stage("a.txt")
        self.run_git("config", "core.commentChar", "-")
        result = self.commit(message(["a.txt"]), "--cleanup=strip")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("comment prefix", result.stderr)


if __name__ == "__main__":
    unittest.main()
