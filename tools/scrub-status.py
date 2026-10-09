#!/usr/bin/env python3
"""Copies a status file with cwd, name and socket path replaced by placeholders: scrub-status.py SRC DST"""
import json, sys

d = json.load(open(sys.argv[1]))
if "name" in d:
    d["name"] = "<name>"
if "cwd" in d:
    d["cwd"] = "/Users/<user>/Sites/<project>"
if "messagingSocketPath" in d:
    d["messagingSocketPath"] = "/tmp/cc-socks/<pid>.sock"
d.pop("bridgeSessionId", None)
json.dump(d, open(sys.argv[2], "w"), indent=1)
