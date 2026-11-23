#!/usr/bin/env bash
# Usage: send-to-worker.sh <session> <message>
# Types "From the control session: <message>" into a worker session and submits it.
set -euo pipefail

[[ $# -ge 2 ]] || { echo "usage: $(basename "$0") <session> <message>" >&2; exit 2; }
session=$1
shift

exec "$(dirname "$0")/send-to-pane.sh" "$session" "From the control session: $*"
