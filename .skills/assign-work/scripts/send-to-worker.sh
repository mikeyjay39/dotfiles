#!/usr/bin/env bash
# Usage: send-to-worker.sh <session> <message>
# Send to the registered worker pane, or to the only agent pane in an older session.
set -euo pipefail
[[ $# -ge 2 ]] || { echo "usage: $(basename "$0") <session> <message>" >&2; exit 2; }
session=$1
shift
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
pane=$("$script_dir/worker-pane.sh" "$session")
exec "$script_dir/send-to-pane.sh" "$pane" "From the control session: $*"
