#!/usr/bin/env python3
"""Keeps only the record kinds 1UP reads from a transcript, scrubbed: scrub-transcript.py SRC DST [TAIL_LINES]"""
import json, sys

src, dst = sys.argv[1], sys.argv[2]
tail = int(sys.argv[3]) if len(sys.argv) > 3 else 40
kept = []
with open(src, encoding="utf-8", errors="replace") as fh:
    for line in fh:
        if '"turn_duration"' not in line and '"custom-title"' not in line and '"ai-title"' not in line:
            continue
        try:
            d = json.loads(line)
        except ValueError:
            continue
        t = d.get("type")
        if not (t in ("custom-title", "ai-title") or (t == "system" and d.get("subtype") == "turn_duration")):
            continue
        keep = {k: d[k] for k in ("type", "subtype", "durationMs", "timestamp", "isSidechain", "version") if k in d}
        if t == "custom-title":
            keep["customTitle"] = "<custom title>"
        if t == "ai-title":
            keep["aiTitle"] = "<ai title>"
        keep["sessionId"] = "<session>"
        kept.append(json.dumps(keep))
with open(dst, "w") as out:
    out.write("\n".join(kept[-tail:]) + ("\n" if kept else ""))
