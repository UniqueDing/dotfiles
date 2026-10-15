#!/usr/bin/env python3
"""Offline regression tests for scripts/bw.sh host-scoped file routing."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "bw.sh"
SHARED_FILES = [
    ".ssh/config",
    ".ssh/id_rsa",
    ".ssh/id_rsa.pub",
    ".local/.wakatime.cfg",
    ".config/zsh/env.local.zsh",
]


FAKE_BW = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path

args = sys.argv[1:]
log = Path(os.environ["FAKE_BW_LOG"])
with log.open("a", encoding="utf-8") as f:
    f.write(json.dumps(args) + "\n")
state_path = Path(os.environ["FAKE_BW_STATE"])
state = json.loads(state_path.read_text(encoding="utf-8"))
items = state.setdefault("items", [])

def save():
    state_path.write_text(json.dumps(state), encoding="utf-8")

if args == ["unlock", "--raw"]:
    print("fixture-session")
elif args == ["sync"]:
    pass
elif args[:2] == ["list", "folders"]:
    print(json.dumps([{"id": "fixture-folder", "name": "dotfiles"}]))
elif args[:2] == ["list", "items"]:
    search = args[args.index("--search") + 1] if "--search" in args else None
    result = [x for x in items if x.get("folderId") == "fixture-folder"]
    if search is not None:
        result = [x for x in result if search in x.get("name", "")]
    print(json.dumps(result))
elif args[:2] == ["get", "template"] and args[2:] == ["item"]:
    print(json.dumps({"type": 2, "name": "", "folderId": "", "notes": "", "secureNote": {"type": 0}}))
elif args[:2] == ["get", "item"]:
    item = next((x for x in items if x.get("id") == args[2]), None)
    if item is None:
        sys.exit(1)
    print(json.dumps(item))
elif args == ["encode"]:
    sys.stdout.write(sys.stdin.read())
elif args[:2] == ["create", "item"]:
    item = json.loads(sys.stdin.read())
    item["id"] = "fixture-" + str(state.get("next_id", 1))
    state["next_id"] = state.get("next_id", 1) + 1
    items.append(item)
    save()
    print(json.dumps(item))
elif args[:2] == ["edit", "item"]:
    item = json.loads(sys.stdin.read())
    old = next((x for x in items if x.get("id") == args[2]), None)
    if old is None:
        sys.exit(1)
    item["id"] = old["id"]
    items[items.index(old)] = item
    save()
    print(json.dumps(item))
else:
    print("unsupported fake bw command: " + repr(args), file=sys.stderr)
    sys.exit(2)
'''


FAKE_HOSTNAME = r'''#!/bin/sh
if [ "${1-}" = "-s" ]; then
  printf '%s\n' "$FAKE_HOSTNAME"
else
  printf '%s\n' "$FAKE_HOSTNAME"
fi
'''


FAILING_MKTEMP = r'''#!/usr/bin/env python3
import os, sys, tempfile
from pathlib import Path

counter = Path(os.environ["FAKE_MKTEMP_COUNT"])
count = int(counter.read_text() if counter.exists() else "0") + 1
counter.write_text(str(count))
if count == 2:
    print("fixture mktemp failure", file=sys.stderr)
    sys.exit(1)
fd, name = tempfile.mkstemp(dir=os.environ["TMPDIR"])
os.close(fd)
print(name)
'''


class BwHostFilesTests(unittest.TestCase):
    def setUp(self):
        if not shutil.which("jq"):
            self.skipTest("jq is a runtime dependency of bw.sh and is not installed")
        temp_base = "/tmp/opencode" if Path("/tmp/opencode").is_dir() else None
        self.temp = tempfile.TemporaryDirectory(prefix="opencode-bw-test-", dir=temp_base)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.bin = self.root / "bin"
        self.tmpdir = self.root / "tmp"
        self.home.mkdir()
        self.bin.mkdir()
        self.tmpdir.mkdir()
        self.state_path = self.root / "vault.json"
        self.log_path = self.root / "bw.log"
        self.state_path.write_text(json.dumps({"items": [], "next_id": 1}), encoding="utf-8")
        self._executable(self.bin / "bw", FAKE_BW)
        self._executable(self.bin / "hostname", FAKE_HOSTNAME)
        self.env = os.environ.copy()
        for key in ("BW_SESSION", "BW_PASSWORD", "BW_CLIENTID", "BW_CLIENTSECRET"):
            self.env.pop(key, None)
        self.env.update({
            "HOME": str(self.home),
            "TMPDIR": str(self.tmpdir),
            "PATH": str(self.bin) + os.pathsep + self.env.get("PATH", ""),
            "FAKE_BW_STATE": str(self.state_path),
            "FAKE_BW_LOG": str(self.log_path),
            "FAKE_HOSTNAME": "alpha",
        })
        for relative in SHARED_FILES:
            path = self.home / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("safe test fixture: " + relative + "\n", encoding="utf-8")

    def tearDown(self):
        self.temp.cleanup()

    @staticmethod
    def _executable(path, content):
        path.write_text(content, encoding="utf-8")
        path.chmod(0o755)

    def _variant(self, replacements):
        text = SCRIPT.read_text(encoding="utf-8")
        for old, new in replacements:
            if old not in text:
                self.fail("expected source fragment not found: " + old)
            text = text.replace(old, new, 1)
        path = self.root / ("variant-" + str(len(list(self.root.glob("variant-*.sh")))) + ".sh")
        self._executable(path, text)
        return path

    def _run(self, *args, host=None, script=None, input_text=None):
        env = self.env.copy()
        if host is not None:
            env["FAKE_HOSTNAME"] = host
        result = subprocess.run(
            ["bash", str(script or SCRIPT), *args],
            env=env,
            input=input_text,
            text=True,
            capture_output=True,
            check=False,
        )
        return result

    def _state(self):
        return json.loads(self.state_path.read_text(encoding="utf-8"))

    def _seed_item(self, name, notes, item_id=None):
        state = self._state()
        item_id = item_id or "seed-" + str(len(state["items"]))
        state["items"].append({
            "id": item_id,
            "type": 2,
            "folderId": "fixture-folder",
            "name": name,
            "notes": notes,
            "secureNote": {"type": 0},
        })
        self.state_path.write_text(json.dumps(state), encoding="utf-8")
        return item_id

    def _seed_all_file_items(self, mismatch=False):
        for relative in SHARED_FILES:
            local = (self.home / relative).read_text(encoding="utf-8")
            notes = "different remote fixture" if mismatch else local.rstrip("\n")
            self._seed_item(relative, notes)
        relative = ".config/opencode-telegram-bot/env.alpha.zsh"
        host_path = self.home / relative
        host_path.parent.mkdir(parents=True, exist_ok=True)
        host_path.write_text("safe host test fixture\n", encoding="utf-8")
        notes = "different remote host fixture" if mismatch else "safe host test fixture"
        self._seed_item("hosts/alpha/" + relative, notes)

    def _assert_tmpdir_empty(self):
        self.assertEqual(list(self.tmpdir.iterdir()), [])

    def _calls(self):
        if not self.log_path.exists():
            return []
        return [json.loads(line) for line in self.log_path.read_text(encoding="utf-8").splitlines()]

    def test_files_and_help_do_not_call_bw(self):
        files = self._run("files")
        self.assertEqual(files.returncode, 0, files.stderr)
        listed = files.stdout.splitlines()
        self.assertEqual(listed[:len(SHARED_FILES)], SHARED_FILES)
        self.assertEqual(listed[-1], ".config/opencode-telegram-bot/env.alpha.zsh")
        help_result = self._run("--help")
        self.assertEqual(help_result.returncode, 0, help_result.stderr)
        self.assertEqual(self._calls(), [])

    def test_shared_legacy_names_and_host_namespace_push(self):
        host_path = self.home / ".config/opencode-telegram-bot/env.alpha.zsh"
        host_path.parent.mkdir(parents=True)
        host_path.write_text("alpha host fixture\n", encoding="utf-8")
        result = self._run("-y", "push")
        self.assertEqual(result.returncode, 0, result.stderr)
        names = {item["name"] for item in self._state()["items"]}
        self.assertTrue(set(SHARED_FILES) <= names)
        self.assertIn("hosts/alpha/.config/opencode-telegram-bot/env.alpha.zsh", names)
        self.assertNotIn("hosts/alpha/.ssh/config", names)

    def test_same_host_path_is_namespaced_per_host_and_supports_spaces(self):
        local_path = ".config/demo settings/config file.ini"
        script = self._variant([(
            '  ".config/opencode-telegram-bot/env.${HOST}.zsh"',
            '  ".config/demo settings/config file.ini"',
        )])
        path = self.home / local_path
        path.parent.mkdir(parents=True)
        path.write_text("alpha fixture", encoding="utf-8")
        alpha = self._run("-y", "push", host="alpha", script=script)
        self.assertEqual(alpha.returncode, 0, alpha.stderr)
        path.write_text("beta fixture", encoding="utf-8")
        beta = self._run("-y", "push", host="beta", script=script)
        self.assertEqual(beta.returncode, 0, beta.stderr)
        items = {item["name"]: item["notes"] for item in self._state()["items"]}
        self.assertEqual(items["hosts/alpha/" + local_path], "alpha fixture")
        self.assertEqual(items["hosts/beta/" + local_path], "beta fixture")

    def test_absolute_home_aliases_normalize_for_shared_and_host_scope(self):
        script = self._variant([
            ('  ".ssh/config"', '  "$HOME/.ssh/config"'),
            ('  ".config/opencode-telegram-bot/env.${HOST}.zsh"', '  "$HOME/.config/opencode-telegram-bot/env.${HOST}.zsh"'),
        ])
        host_path = self.home / ".config/opencode-telegram-bot/env.alpha.zsh"
        host_path.parent.mkdir(parents=True)
        host_path.write_text("host fixture\n", encoding="utf-8")
        result = self._run("-y", "push", script=script)
        self.assertEqual(result.returncode, 0, result.stderr)
        names = {item["name"] for item in self._state()["items"]}
        self.assertIn(".ssh/config", names)
        self.assertIn("hosts/alpha/.config/opencode-telegram-bot/env.alpha.zsh", names)
        self.assertFalse(any(name.startswith("hosts/alpha/home/") for name in names))

    def test_missing_host_file_is_optional_for_push_and_pull(self):
        push = self._run("-y", "push")
        self.assertEqual(push.returncode, 0, push.stderr)
        self.assertIn("skip missing optional file", push.stdout)
        pull = self._run("-y", "pull")
        self.assertEqual(pull.returncode, 0, pull.stderr)
        self.assertIn("skip optional item not found: hosts/alpha/", pull.stdout)

    def test_pull_uses_host_key_local_path_and_private_permissions(self):
        for relative in SHARED_FILES:
            self._seed_item(relative, (self.home / relative).read_text(encoding="utf-8"))
        relative = ".config/opencode-telegram-bot/env.alpha.zsh"
        self._seed_item("hosts/alpha/" + relative, "pulled host fixture")
        result = self._run("-y", "pull")
        self.assertEqual(result.returncode, 0, result.stderr)
        target = self.home / relative
        self.assertEqual(target.read_text(encoding="utf-8"), "pulled host fixture\n")
        self.assertEqual(target.stat().st_mode & 0o777, 0o600)
        self.assertFalse((self.home / "hosts/alpha" / relative).exists())

    def test_pull_never_falls_back_to_shared_or_another_host(self):
        relative = ".config/demo/config.ini"
        script = self._variant([(
            '  ".config/opencode-telegram-bot/env.${HOST}.zsh"',
            '  ".config/demo/config.ini"',
        )])
        target = self.home / relative
        target.parent.mkdir(parents=True)
        target.write_text("leave local unchanged\n", encoding="utf-8")
        for shared in SHARED_FILES:
            self._seed_item(shared, (self.home / shared).read_text(encoding="utf-8"))
        shared_id = self._seed_item(relative, "shared candidate\n")
        other_id = self._seed_item("hosts/beta/" + relative, "beta candidate\n")
        result = self._run("-y", "pull", host="alpha", script=script)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(target.read_text(encoding="utf-8"), "leave local unchanged\n")
        self.assertIn("skip optional item not found: hosts/alpha/" + relative, result.stdout)
        fetched = [call[2] for call in self._calls() if call[:2] == ["get", "item"]]
        self.assertNotIn(shared_id, fetched)
        self.assertNotIn(other_id, fetched)

    def test_missing_shared_file_still_fails(self):
        (self.home / ".ssh/config").unlink()
        result = self._run("-y", "push")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing file:", result.stderr)

    def test_push_unchanged_multiple_items_cleans_temporary_files(self):
        self._seed_all_file_items()
        result = self._run("-y", "push")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count("no changes:"), len(SHARED_FILES) + 1)
        self._assert_tmpdir_empty()

    def test_pull_unchanged_multiple_items_cleans_temporary_files(self):
        self._seed_all_file_items()
        result = self._run("-y", "pull")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count("no changes:"), len(SHARED_FILES) + 1)
        self._assert_tmpdir_empty()

    def test_declined_push_updates_clean_temporary_files_each_iteration(self):
        self._seed_all_file_items(mismatch=True)
        result = self._run("push", input_text="n\n" * (len(SHARED_FILES) + 1))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count("skip:"), len(SHARED_FILES) + 1)
        self._assert_tmpdir_empty()

    def test_declined_push_creates_clean_temporary_files_each_iteration(self):
        host_path = self.home / ".config/opencode-telegram-bot/env.alpha.zsh"
        host_path.parent.mkdir(parents=True)
        host_path.write_text("safe host test fixture\n", encoding="utf-8")
        result = self._run("push", input_text="n\n" * (len(SHARED_FILES) + 1))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count("skip:"), len(SHARED_FILES) + 1)
        self._assert_tmpdir_empty()

    def test_declined_pull_cleans_temporary_files_each_iteration(self):
        self._seed_all_file_items(mismatch=True)
        result = self._run("pull", input_text="n\n" * (len(SHARED_FILES) + 1))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count("skip:"), len(SHARED_FILES) + 1)
        self._assert_tmpdir_empty()

    def test_exit_trap_cleans_first_temp_when_second_mktemp_fails(self):
        self._executable(self.bin / "mktemp", FAILING_MKTEMP)
        self.env["FAKE_MKTEMP_COUNT"] = str(self.root / "mktemp-count")
        result = self._run("-y", "push")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fixture mktemp failure", result.stderr)
        self._assert_tmpdir_empty()

    def test_scope_collision_and_unsafe_hostname_fail_before_bw(self):
        collision = self._variant([(
            '  ".config/opencode-telegram-bot/env.${HOST}.zsh"',
            '  ".ssh/config"',
        )])
        result = self._run("push", script=collision)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("both shared and host scopes", result.stderr)
        self.assertEqual(self._calls(), [])
        unsafe = self._run("push", host="../alpha")
        self.assertNotEqual(unsafe.returncode, 0)
        self.assertIn("unsafe short hostname", unsafe.stderr)
        self.assertEqual(self._calls(), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
