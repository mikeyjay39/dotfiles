#!/usr/bin/env bash
# Usage: opencode-idle.sh <OpenCode-session-id>
# Return 0 for idle, 1 for running, and 2 for unknown. Use the shared V2 server.
set -euo pipefail
[[ $# -eq 1 && "$1" =~ ^ses[a-zA-Z0-9_-]+$ ]] || exit 2
session=$1
info=$(opencode api get "/api/session/$session") || exit 2
active=$(opencode api get /api/session/active) || exit 2
python3 -c '
import json,sys
try:
    session, info, active = sys.argv[1], json.loads(sys.argv[2])["data"], json.loads(sys.argv[3])["data"]
    assert info["id"] == session and isinstance(active, dict)
    assert all(isinstance(v, dict) and v.get("type") == "running" for v in active.values())
    sys.exit(1 if session in active else 0)
except (KeyError, ValueError, TypeError, AssertionError):
    sys.exit(2)
' "$session" "$info" "$active"
