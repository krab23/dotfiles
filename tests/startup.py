"""Measure an already provisioned environment; never install prerequisites."""
import argparse
import json
import os
import pathlib
import platform
import statistics
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--label", required=True, help="Describe native/SSH/WSL and enabled integrations")
parser.add_argument("--output", required=True, type=pathlib.Path)
parser.add_argument("--runs", type=int, default=5)
args = parser.parse_args()
if args.runs < 1:
    parser.error("--runs must be positive")
if args.output.exists():
    parser.error("--output must be a new file")

report = {
    "label": args.label,
    "platform": platform.platform(),
    "wsl": bool(os.environ.get("WSL_DISTRO_NAME")),
    "ssh": bool(os.environ.get("SSH_CONNECTION")),
    "provision_mode": os.environ.get("DOTFILES_NVIM_PROVISION") == "1",
    "runs": args.runs,
    "versions": {},
    "timings": {},
}
nvim_check = '+lua if vim.v.errmsg ~= "" then vim.cmd("cquit 1") end'
with tempfile.TemporaryDirectory(prefix="dotfiles-startup-") as scratch:
    for name, command in (
        ("zsh", ["zsh", "-i", "-c", "exit"]),
        ("nvim", ["nvim", "--headless", "-i", "NONE", nvim_check, "+qa!"]),
    ):
        report["versions"][name] = subprocess.check_output(
            [name, "--version"], text=True, timeout=10
        ).splitlines()[0]
        timings = []
        for run in range(args.runs):
            started = time.perf_counter()
            result = subprocess.run(command, capture_output=True, text=True, timeout=60)
            timings.append(round((time.perf_counter() - started) * 1000, 2))
            if result.returncode:
                raise RuntimeError(f"{name} failed: {result.stderr}")
            # Keep warnings visible: a fast but broken startup is not a win.
            if result.stderr:
                print(f"{name} stderr (run {run + 1}): {result.stderr.strip()}")
        report["timings"][name] = {"milliseconds": timings, "median_ms": statistics.median(timings)}
    trace = pathlib.Path(scratch) / "nvim-startup.log"
    subprocess.run(["nvim", "--headless", "-i", "NONE", "--startuptime", str(trace), nvim_check, "+qa!"],
                   check=True, capture_output=True, timeout=60)
    report["nvim_startuptime"] = trace.read_text()
args.output.write_text(json.dumps(report, indent=2) + "\n")
for name, timing in report["timings"].items():
    print(f"{name}: median {timing['median_ms']} ms ({args.runs} runs)")
print(f"Report: {args.output}")
