#!/bin/zsh
# Copies live status files and transcript tails from this Mac into Tests/OneUpCoreTests/Fixtures/<version>/,
# replacing cwd, names, titles and socket paths with placeholders. Message bodies are never copied.
# Usage: tools/capture-fixtures.sh [--config-dir ~/.claude] [--tail-lines 40]
set -euo pipefail
cd "$(dirname "$0")/.."
config="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
tail_lines=40
while [ $# -gt 0 ]; do
  case "$1" in
    --config-dir) config="$2"; shift 2 ;;
    --tail-lines) tail_lines="$2"; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
[ -d "$config/sessions" ] || { echo "no sessions folder at $config/sessions" >&2; exit 1; }

n=0
for sfile in "$config"/sessions/*.json; do
  [ -f "$sfile" ] || continue
  version=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1])).get("version","unknown"))' "$sfile" 2>/dev/null || echo unknown)
  session=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["sessionId"])' "$sfile" 2>/dev/null || true)
  [ -n "$session" ] || continue
  out="Tests/OneUpCoreTests/Fixtures/$version"
  mkdir -p "$out"
  pid=$(basename "$sfile" .json)
  python3 -I tools/scrub-status.py "$sfile" "$out/status-$pid.json"
  transcript=$(find "$config/projects" -maxdepth 2 -name "$session.jsonl" 2>/dev/null | head -1 || true)
  if [ -n "$transcript" ]; then
    python3 -I tools/scrub-transcript.py "$transcript" "$out/transcript-$pid.jsonl" "$tail_lines"
  fi
  n=$((n + 1))
done
echo "captured $n status files into Tests/OneUpCoreTests/Fixtures/<version>/"
