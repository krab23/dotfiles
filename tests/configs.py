"""Parse repository JSON/TOML; application-specific validation is separate."""
import json
import pathlib
import subprocess
import tomllib

root = pathlib.Path(__file__).resolve().parent.parent
files = subprocess.check_output(
    ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard",
     "--", "*.json", "*.toml"], cwd=root
).decode().split("\0")
for name in filter(None, files):
    path = root / name
    if not path.is_file():
        continue
    with path.open("rb") as stream:
        if path.suffix == ".toml":
            tomllib.load(stream)
        else:
            json.load(stream)
    print(f"PASS: parse {name}")
