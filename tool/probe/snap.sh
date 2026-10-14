#!/usr/bin/env bash
# Saves the probe's latest JSON line as a labelled fixture, once the geometry
# has settled (no new line for SETTLE seconds).
#
# Usage: tool/probe/snap.sh <pose_name> [log-file]
#   e.g. closed, open, book, open_rotated, closed_landscape
set -euo pipefail

NAME="${1:?usage: snap.sh <pose_name> [log-file]}"
if [[ ! "$NAME" =~ ^[a-z][a-z0-9_]*$ ]]; then
  echo "error: pose name must be snake_case, got '$NAME'" >&2
  exit 2
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
LOG="${2:-$HERE/out/session.log}"
OUT="$ROOT/test/fixtures/$NAME.json"
SETTLE="${SETTLE:-2}"

# Transitions emit bursts of intermediate states (stale regions, rotating
# frames). Only snapshot once the log has been quiet for a moment.
age=$(($(date +%s) - $(stat -f %m "$LOG")))
if ((age < SETTLE)); then
  echo "error: geometry still changing (last line ${age}s ago), retry in a few seconds" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
grep '^{' "$LOG" | tail -n 1 | python3 -I -m json.tool --sort-keys >"$OUT"

python3 -I - "$OUT" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
h = d.get("hinge") or {}
v = d["viewBounds"]
print(f"saved {sys.argv[1]}")
print(f"  view {v['w']:g}x{v['h']:g}  {d['interfaceOrientation']}  "
      f"hinge {h.get('status')} {h.get('angleDeg', 0):.1f} deg  bars {d['verticalBarEdge']}")
for r in d["regions"]:
    f = r["frame"]
    state = "active" if r["active"] else "inactive"
    print(f"  {r['kind']:<9} {state:<8} {f['w']:g}x{f['h']:g} at {f['x']:g},{f['y']:g}")
PY
