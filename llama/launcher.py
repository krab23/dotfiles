#!/usr/bin/env python3
"""Explicit, user-local llama-server lifecycle management for Linux/Python 3.11+."""

import argparse
import contextlib
import fcntl
import json
import os
from pathlib import Path
import select
import shutil
import signal
import stat
import subprocess
import sys
import tempfile


class LauncherError(Exception):
    pass


def state_directory():
    base = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
    path = Path(os.environ.get("LLAMA_BACKGROUND_STATE_DIR") or base / "llama-background/ornith")
    if not path.is_absolute():
        raise LauncherError("State directory must be absolute.")
    return path


def check_directory(path):
    info = path.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise LauncherError(f"State directory must be a private, user-owned directory: {path}")


def private_file(path, flags):
    # Nonblocking opens let fstat reject an accidental FIFO instead of hanging.
    fd = os.open(path, flags | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK, 0o600)
    info = os.fstat(fd)
    if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid()
            or info.st_mode & 0o077 or info.st_nlink != 1):
        os.close(fd)
        raise LauncherError(f"Expected a private, user-owned regular file: {path}")
    return fd


@contextlib.contextmanager
def locked(path):
    check_directory(path)
    fd = private_file(path / "lock", os.O_CREAT | os.O_RDWR)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise LauncherError("Another launcher operation is in progress; retry later.") from error
        yield
    finally:
        os.close(fd)


def identity(pid):
    """Boot ID + kernel start tick distinguish stale/reused PIDs; zombies are dead."""
    try:
        proc = Path(f"/proc/{pid}")
        if proc.stat().st_uid != os.getuid():
            return None
        fields = (proc / "stat").read_text().rsplit(")", 1)[1].split()
        if fields[0] in ("Z", "X"):
            return None
        return {
            "pid": pid,
            "start_time": int(fields[19]),
            "boot_id": Path("/proc/sys/kernel/random/boot_id").read_text().strip(),
        }
    except (FileNotFoundError, ProcessLookupError):
        return None


def read_record(path):
    try:
        fd = private_file(path / "process.json", os.O_RDONLY)
    except FileNotFoundError:
        return None
    try:
        with os.fdopen(fd) as stream:
            data = json.loads(stream.read(4096))
        if (not isinstance(data, dict) or set(data) != {"pid", "start_time", "boot_id"}
                or type(data["pid"]) is not int or data["pid"] <= 1
                or type(data["start_time"]) is not int or data["start_time"] <= 0
                or not isinstance(data["boot_id"], str) or not data["boot_id"]):
            raise ValueError("Invalid process identity")
        return data
    except (ValueError, TypeError) as error:
        raise LauncherError("Invalid process.json; refusing to manage an unknown process.") from error


@contextlib.contextmanager
def process_handle(record):
    """Bind signals to a kernel process handle, never to a recyclable numeric PID."""
    if not hasattr(os, "pidfd_open") or not hasattr(signal, "pidfd_send_signal"):
        raise LauncherError("Process control requires Linux pidfd support and Python 3.11+.")
    fd = None
    try:
        if record:
            try:
                fd = os.pidfd_open(record["pid"])
            except ProcessLookupError:
                pass
            if fd is not None and identity(record["pid"]) != record:
                os.close(fd)
                fd = None
        yield fd
    finally:
        if fd is not None:
            os.close(fd)


def positive(value):
    number = int(value)
    if number <= 0:
        raise argparse.ArgumentTypeError("must be positive")
    return number


def command_line(args):
    config = json.loads(Path(__file__).resolve().with_name("ornith.json").read_text())
    override = Path(os.environ.get("LLAMA_BACKGROUND_CONFIG") or
                    Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") /
                    "llama-background/ornith.json")
    if override.exists() or "LLAMA_BACKGROUND_CONFIG" in os.environ:
        local = json.loads(override.read_text())
        if not isinstance(local, dict) or local.keys() - config.keys():
            raise LauncherError("Profile must be an object containing only documented profile keys.")
        config.update(local)
    for key in ("hf_repo", "alias", "host"):
        if not isinstance(config[key], str) or not config[key] or config[key].startswith("-"):
            raise LauncherError(f"Invalid profile setting: {key}")
    for key in ("port", "context", "predict"):
        value = getattr(args, key)
        if value is not None:
            config[key] = value
        if type(config[key]) is not int or config[key] <= 0:
            raise LauncherError(f"Profile {key} must be a positive integer.")
    if config["port"] > 65535:
        raise LauncherError("Port must be between 1 and 65535.")
    if (not isinstance(config["extra_args"], list)
            or any(not isinstance(item, str) or "\0" in item for item in config["extra_args"])):
        raise LauncherError("Profile extra_args must be an array of argument strings.")
    server = os.path.expanduser(args.server or os.environ.get("LLAMA_SERVER_BIN") or "llama-server")
    executable = shutil.which(server)
    if not executable:
        raise LauncherError("llama-server is missing; install it or set LLAMA_SERVER_BIN.")
    model = args.model or os.environ.get("LLAMA_MODEL")
    if model and args.download:
        raise LauncherError("Choose a local model OR --download, not both (check LLAMA_MODEL too).")
    if model:
        model_path = Path(model).expanduser().resolve()
        if not model_path.is_file():
            raise LauncherError(f"Local model does not exist: {model_path}")
        model_args = ["--model", str(model_path)]
    elif args.download:
        model_args = ["-hf", config["hf_repo"]]
    else:
        raise LauncherError("Supply --model /path/to/model.gguf (or LLAMA_MODEL), or explicitly allow --download.")
    command = [executable, *model_args, "--alias", config["alias"], "--host", config["host"],
               "--port", str(config["port"]), "-c", str(config["context"]),
               "-n", str(config["predict"]), *config["extra_args"]]
    if args.gpu_layers is not None:
        command += ["--n-gpu-layers", str(args.gpu_layers)]
    return command


def start(path, args):
    # Validate every input before creating state or spawning anything.
    command = command_line(args)
    # Probe kernel support before starting a child we might be unable to stop.
    with process_handle(identity(os.getpid())):
        pass
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    with locked(path):
        with process_handle(read_record(path)) as handle:
            if handle is not None:
                print("Ornith is already running; use status or stop first.")
                return 0
        log = private_file(path / "server.log", os.O_CREAT | os.O_WRONLY | os.O_APPEND)
        try:
            process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
        finally:
            os.close(log)
        pending = None
        try:
            record = identity(process.pid)
            if record is None:
                raise LauncherError(f"Server exited during startup; inspect {path / 'server.log'}")
            with tempfile.NamedTemporaryFile(mode="w", dir=path, prefix=".process-", delete=False) as stream:
                pending = Path(stream.name)
                json.dump(record, stream)
                stream.write("\n")
            os.replace(pending, path / "process.json")
            try:
                process.wait(timeout=0.2)
            except subprocess.TimeoutExpired:
                print(f"Started Ornith (PID {process.pid}); model readiness is not checked. Log: {path / 'server.log'}")
                return 0
            raise LauncherError(f"Server exited with status {process.returncode}; inspect {path / 'server.log'}")
        except BaseException:
            # Popen owns this child; an unreaped child cannot have its PID reused.
            if process.poll() is None:
                process.kill()
            process.wait()
            (path / "process.json").unlink(missing_ok=True)
            raise
        finally:
            if pending is not None:
                pending.unlink(missing_ok=True)


def stop(path, args):
    if not path.exists():
        print("Ornith is stopped (no managed process).")
        return 0
    with locked(path):
        with process_handle(read_record(path)) as handle:
            if handle is not None:
                try:
                    signal.pidfd_send_signal(handle, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                if not select.select([handle], [], [], args.timeout)[0]:
                    raise LauncherError("Server did not stop in time; record retained. No force-kill was sent.")
            (path / "process.json").unlink(missing_ok=True)
        print("Ornith is stopped.")
    return 0


def status(path):
    if path.exists():
        check_directory(path)
        record = read_record(path)
        with process_handle(record) as handle:
            if handle is not None:
                print(f"Ornith is running (PID {record['pid']}); model readiness is not checked.")
                return 0
    print("Ornith is stopped (no live managed process).")
    return 3


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    launch = commands.add_parser("start", help="start only on explicit request; never called by bootstrap")
    models = launch.add_mutually_exclusive_group()
    models.add_argument("--model", help="local GGUF path; defaults to LLAMA_MODEL")
    models.add_argument("--download", action="store_true", help="allow llama-server to fetch the profile's HF model")
    launch.add_argument("--server", help="llama-server executable; defaults to LLAMA_SERVER_BIN or PATH")
    for option in ("port", "context", "predict"):
        launch.add_argument(f"--{option}", type=positive)
    launch.add_argument("--gpu-layers", type=int, help="explicit runtime offload setting; no driver/toolkit installation")
    halt = commands.add_parser("stop")
    halt.add_argument("--timeout", type=positive, default=10, help="seconds to wait after SIGTERM; never force-kills")
    commands.add_parser("status")
    logs = commands.add_parser("logs")
    logs.add_argument("--follow", action="store_true")
    logs.add_argument("--lines", type=positive, default=40)
    args = parser.parse_args()
    path = state_directory()
    if args.action == "start":
        return start(path, args)
    if args.action == "stop":
        return stop(path, args)
    if args.action == "status":
        return status(path)
    if not path.exists():
        raise LauncherError("No managed log yet; start the server explicitly first.")
    check_directory(path)
    os.close(private_file(path / "server.log", os.O_RDONLY))
    command = ["tail", "-n", str(args.lines)]
    if args.follow:
        command += ["-f"]
    os.execvp("tail", [*command, "--", str(path / "server.log")])


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (LauncherError, OSError, ValueError) as error:
        print(f"llama-background: {error}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)
