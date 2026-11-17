#!/usr/bin/env python3
"""globalkeys.py [--check] FILE JSON: set LXQt global shortcuts in FILE (~/.config/lxqt/globalkeyshortcuts.conf).

JSON is the role's lxqt_keys list: [file, "<Key>.<id>", option, value] rows. Per key, our Exec section gets the given
options; every other binding of the same key (e.g. the panel volume widget's path=/panel/volume/up) is kept but
disabled, so a key does one thing. Matched by key, not section number (lxqt-globalkeysd renumbers on save), and
Exec compared without quotes, so the file stays unchanged once it is right. Prints CHANGED when the file differs
(with --check: would differ; nothing is written).
"""
import json
import re
import sys

args = sys.argv[1:]
check = args[:1] == ["--check"]
if check:
    args = args[1:]
path, rows = args[0], json.loads(args[1])

want = {}  # key -> (section name to use if the key has none yet, {option: value})
for _file, section, option, value in rows:
    key = section.rsplit(".", 1)[0]
    want.setdefault(key, (section, {}))[1][option] = str(value).lower() if isinstance(value, bool) else str(value)

try:
    text = open(path).read()
except FileNotFoundError:
    text = ""

# Split into [header, body lines] blocks; the part before the first header keeps header None.
blocks, cur = [], [None, []]
for line in text.splitlines():
    m = re.match(r"^\[(.+)\]\s*$", line)
    if m:
        blocks.append(cur)
        cur = [m.group(1), []]
    else:
        cur[1].append(line)
blocks.append(cur)

def norm(option, value):
    """lxqt-globalkeysd re-quotes Exec arguments on save ("--min-value=1%"); compare without quotes."""
    if option == "Exec":
        return [a.strip().strip('"') for a in value.split(",")]
    return value.strip()


def parse(body):
    return dict(l.split("=", 1) for l in body if "=" in l)


# Matched by KEY, not by section number (lxqt-globalkeysd renumbers on save). Per managed key, the first section
# without a built-in `path` action is ours: set to the wanted values, or left byte for byte if it already matches.
# Every other binding of that key stays but is disabled: the panel's volume widget re-registers its own volume
# shortcuts (path=/panel/volume/...) whenever it starts, so deleting them only brings them back enabled.
ours = {}
for i, (name, body) in enumerate(blocks):
    key = name.rsplit(".", 1)[0] if name else None
    if key in want and key not in ours and "path" not in parse(body):
        ours[key] = i

out = []
for i, (name, body) in enumerate(blocks):
    key = name.rsplit(".", 1)[0] if name else None
    if key in want:
        have = parse(body)
        if ours.get(key) == i:
            opts = want[key][1]
            if any(norm(k, have.get(k, "")) != norm(k, v) for k, v in opts.items()):
                kept = [l for l in body if l.strip() and l.split("=", 1)[0] not in opts]
                body = kept + [f"{k}={v}" for k, v in opts.items()] + [""]
        elif have.get("Enabled", "true") != "false":
            body = [l for l in body if not l.startswith("Enabled=")]
            body = (["Enabled=false"] + [l for l in body if l.strip()]) + [""]
    out.append((name, body))
for key, (section, opts) in want.items():
    if key not in ours:
        out.append((section, [f"{k}={v}" for k, v in opts.items()] + [""]))

lines = []
for name, body in out:
    if name is not None:
        lines.append(f"[{name}]")
    lines.extend(body)
new = "\n".join(lines).rstrip("\n") + "\n"
if new != text:
    print("CHANGED")
    if not check:
        open(path, "w").write(new)
