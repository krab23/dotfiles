"""Offline launcher checks: only disposable fake servers, never models or GPUs."""

import contextlib
import io
import json
import os
from pathlib import Path
import runpy
import signal
import subprocess
import sys
import tempfile
import threading
import time
from types import SimpleNamespace
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parent.parent
LAUNCHER = SimpleNamespace(**runpy.run_path(str(ROOT / "llama/launcher.py")))


class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="dotfiles-llama-", dir=os.environ.get("TMPDIR", "/tmp"))
        self.addCleanup(self.scratch.cleanup)
        self.home = Path(self.scratch.name) / "home with spaces"
        self.home.mkdir()
        self.state = self.home / "state/llama-background/ornith"
        self.fake = self.home / "fake server"
        self.fake.write_text(
            f"#!{sys.executable}\n"
            "import json, os, signal, sys, time\n"
            "from pathlib import Path\n"
            "Path(os.environ['FAKE_ARGS']).write_text(json.dumps(sys.argv[1:]))\n"
            "if os.environ.get('FAKE_EXIT'): sys.exit(7)\n"
            "if os.environ.get('FAKE_IGNORE_TERM'): signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
            "print('fake ready', flush=True)\n"
            "Path(os.environ['FAKE_ARGS'] + '.ready-' + str(os.getpid())).touch()\n"
            "while True: time.sleep(1)\n"
        )
        self.fake.chmod(0o700)
        self.model = self.home / "test model.gguf"
        self.model.touch()
        env = {
            "HOME": str(self.home), "PATH": os.environ["PATH"],
            "XDG_CONFIG_HOME": str(self.home / "config"), "XDG_STATE_HOME": str(self.home / "state"),
            "LLAMA_SERVER_BIN": str(self.fake), "FAKE_ARGS": str(self.home / "args.json"),
        }
        self.env = mock.patch.dict(os.environ, env, clear=True)
        self.env.start()
        self.addCleanup(self.env.stop)
        self.children = []
        original = subprocess.Popen

        def spawn(*args, **kwargs):
            child = original(*args, **kwargs)
            self.children.append(child)
            return child

        self.spawner = mock.patch.object(subprocess, "Popen", side_effect=spawn)
        self.spawner.start()
        self.addCleanup(self.spawner.stop)
        self.addCleanup(self.reap_children)

    def reap_children(self):
        # These are our own unreaped Popen children, not arbitrary PIDs from files.
        for child in self.children:
            if child.poll() is None:
                child.kill()
            child.wait(timeout=5)

    def invoke(self, *args, expected=0):
        output = io.StringIO()
        previous_children = len(self.children)
        with mock.patch.object(sys, "argv", ["llama-background", *args]), contextlib.redirect_stdout(output):
            try:
                result = LAUNCHER.main()
            except (LAUNCHER.LauncherError, OSError, ValueError) as error:
                result = 1
                output.write(str(error))
        self.assertEqual(result, expected, output.getvalue())
        # Production reports process launch, not readiness. Give the fake server
        # its own readiness barrier so assertions do not depend on a fast host.
        if result == 0 and args[0] == "start" and len(self.children) > previous_children:
            child = self.children[-1]
            ready = Path(os.environ["FAKE_ARGS"] + f".ready-{child.pid}")
            deadline = time.monotonic() + 5
            while not ready.exists() and child.poll() is None and time.monotonic() < deadline:
                time.sleep(0.01)
            self.assertTrue(ready.exists(), "fake server did not become ready")
        return output.getvalue()

    def start(self, *args):
        return self.invoke("start", "--model", str(self.model), *args)

    def test_read_only_commands_and_invalid_start_create_nothing(self):
        self.invoke("status", expected=3)
        self.invoke("stop")
        self.invoke("logs", expected=1)
        self.invoke("start", expected=1)
        self.invoke("start", "--model", "/missing/model", expected=1)
        self.invoke("start", "--download", "--server", "/missing/server", expected=1)
        self.invoke("start", "--download", "--port", "65536", expected=1)
        self.assertFalse(self.state.exists())
        self.assertFalse(self.children)

    def test_lifecycle_and_exact_arguments(self):
        self.start("--context", "4096", "--predict", "512", "--gpu-layers", "0")
        args = json.loads((self.home / "args.json").read_text())
        self.assertEqual(args[0:2], ["--model", str(self.model)])
        self.assertNotIn("-hf", args)
        for key, value in (("--alias", "ornith"), ("--host", "127.0.0.1"),
                           ("--port", "8080"), ("-c", "4096"), ("-n", "512"),
                           ("--n-gpu-layers", "0")):
            self.assertEqual(args[args.index(key) + 1], value)
        self.assertEqual(self.state.stat().st_mode & 0o777, 0o700)
        for name in ("process.json", "server.log", "lock"):
            self.assertEqual((self.state / name).stat().st_mode & 0o777, 0o600)
        before = {p.name: p.read_bytes() for p in self.state.iterdir()}
        self.assertIn("running", self.invoke("status"))
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.state.iterdir()})
        self.assertIn("already running", self.start())
        self.assertEqual(len(self.children), 1)
        self.invoke("stop")
        self.invoke("stop")
        self.invoke("status", expected=3)
        self.assertFalse((self.state / "process.json").exists())
        self.assertEqual(self.children[0].wait(timeout=5), -signal.SIGTERM)

    def test_download_is_explicit_and_config_is_data(self):
        config = self.home / "config/llama-background/ornith.json"
        config.parent.mkdir(parents=True)
        config.write_text(json.dumps({"context": 2048, "predict": 256, "port": 8099,
                                      "extra_args": ["--jinja", "literal; not a shell command"]}))
        self.invoke("start", "--download")
        args = json.loads((self.home / "args.json").read_text())
        self.assertEqual(args[0:2], ["-hf", "ornith-ai/Ornith-1.5-9B-GGUF:Q4_K_M"])
        self.assertEqual(args[args.index("--port") + 1], "8099")
        self.assertIn("literal; not a shell command", args)
        self.invoke("stop")
        os.environ["LLAMA_MODEL"] = str(self.model)
        self.invoke("start", "--download", expected=1)
        self.invoke("start")
        self.invoke("stop")
        config.write_text('{"unknown":true}')
        self.invoke("start", expected=1)

    def test_stale_identity_never_signals_unrelated_process(self):
        self.start()
        record = self.state / "process.json"
        data = json.loads(record.read_text())
        original = dict(data)
        data["start_time"] += 1
        record.write_text(json.dumps(data))
        self.invoke("status", expected=3)
        self.invoke("stop")
        self.assertIsNone(self.children[0].poll())
        # A previous boot must likewise never match, even for the same PID/tick.
        original["boot_id"] = "previous-boot"
        record.write_text(json.dumps(original))
        record.chmod(0o600)
        self.invoke("stop")
        self.assertIsNone(self.children[0].poll())

    def test_corrupt_records_and_unsafe_state_fail_closed(self):
        self.state.mkdir(parents=True, mode=0o700)
        record = self.state / "process.json"
        for text in ('not JSON', '{"pid":-1}', '[]'):
            record.write_text(text)
            record.chmod(0o600)
            self.invoke("stop", expected=1)
            self.start_error()
            self.assertEqual(record.read_text(), text)
        record.unlink()
        record.symlink_to(self.model)
        self.invoke("stop", expected=1)
        self.assertTrue(record.is_symlink())
        record.unlink()
        os.mkfifo(record, 0o600)
        self.invoke("stop", expected=1)
        record.unlink()
        (self.state / "server.log").symlink_to(self.model)
        self.start_error()
        self.assertEqual(self.model.read_bytes(), b"")
        self.state.chmod(0o755)
        self.invoke("status", expected=1)
        self.invoke("stop", expected=1)
        self.assertFalse(self.children)

    def start_error(self):
        self.invoke("start", "--model", str(self.model), expected=1)

    def test_early_exit_cleans_record_but_keeps_log(self):
        os.environ["FAKE_EXIT"] = "1"
        self.start_error()
        self.assertFalse((self.state / "process.json").exists())
        self.assertTrue((self.state / "server.log").exists())
        self.assertFalse(list(self.state.glob(".process-*")))

    def test_stop_timeout_preserves_record_without_force_kill(self):
        os.environ["FAKE_IGNORE_TERM"] = "1"
        self.start()
        self.invoke("stop", "--timeout", "1", expected=1)
        self.assertTrue((self.state / "process.json").exists())
        self.assertIsNone(self.children[0].poll())

    def test_concurrent_start_is_locked(self):
        args = SimpleNamespace(model=str(self.model), download=False, server=None,
                               port=None, context=None, predict=None, gpu_layers=None)
        self.state.mkdir(parents=True, mode=0o700)
        with LAUNCHER.locked(self.state):
            failures = []

            def contender():
                try:
                    LAUNCHER.start(self.state, args)
                except LAUNCHER.LauncherError as error:
                    failures.append(str(error))

            worker = threading.Thread(target=contender)
            worker.start()
            worker.join(timeout=5)
            self.assertFalse(worker.is_alive())
            self.assertEqual(len(failures), 1)
            self.assertIn("in progress", failures[0])
            self.assertFalse(self.children)

    def test_logs_use_managed_path_and_preserve_follow_option(self):
        self.start()
        with mock.patch.object(os, "execvp") as execute:
            self.invoke("logs", "--lines", "2", expected=None)
            execute.assert_called_once_with("tail", ["tail", "-n", "2", "--", str(self.state / "server.log")])
        with mock.patch.object(os, "execvp") as execute:
            self.invoke("logs", "--follow", expected=None)
            self.assertIn("-f", execute.call_args.args[1])
        self.invoke("stop")


if __name__ == "__main__":
    unittest.main()
