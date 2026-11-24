#!/usr/bin/env bash
# Mock tmux and desktop commands. Never load the live config.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp/opencode}/tmux-hook-tests.XXXXXX")
trap 'rm -r -- "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home/.config/tmux"
export MOCK_LOG="$tmp/log" HOME="$tmp/home" XDG_RUNTIME_DIR="$tmp"
export REAL_FLOCK
REAL_FLOCK=$(command -v flock)
export PATH="$tmp/bin:$PATH"
cat >"$tmp/bin/mock" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
name=${0##*/}
printf '%s' "$name" >>"$MOCK_LOG"
printf ' <%s>' "$@" >>"$MOCK_LOG"
printf '\n' >>"$MOCK_LOG"
case "$name" in
  tmux)
    case "$1" in
      show-options)
        if [[ "${*: -1}" == @opencode-binding ]]; then
          [[ ${MOCK_BINDING_FAIL:-0} == 0 ]] || exit 1
          if [[ -n ${MOCK_BINDING_FILE:-} ]]; then cat "$MOCK_BINDING_FILE"
          else printf '%s\n' "${MOCK_BINDING:-ses_a|100|client-a}"; fi
        elif [[ "$4" == %7 ]]; then echo "${MOCK_PANE_A:-done}"
        else echo "${MOCK_PANE_B:-needs-input}"; fi ;;
      list-sessions)
        [[ ${MOCK_TMUX_FAIL:-0} == 0 ]] || exit 1
        if [[ ${2:-} == -F ]]; then printf '%s\n' "${MOCK_SESSIONS:-\$1 }"; fi ;;
      list-panes)
        if [[ "${*: -1}" == '#{pane_id}' ]]; then printf '%%7\n%%8\n'
        else printf '%%7 claude\n%%8 cursor-agent\n%%9 opencode\n%%10 bash\n'; fi ;;
      list-clients) echo client-1 ;;
      list-windows) printf '%s\n' "${MOCK_WINDOWS:-\$1 off}" ;;
      display-message) if [[ ${2:-} == -p ]]; then echo worker:1; fi ;;
      set-option)
        [[ ${MOCK_SET_FAIL:-0} == 0 ]] || exit 1
        if [[ ${5:-} == @opencode-binding && -n ${MOCK_BINDING_FILE:-} ]]; then printf '%s\n' "$6" >"$MOCK_BINDING_FILE"; fi ;;
      switch-client) ;;
      *) exit 91 ;;
    esac ;;
esac
MOCK
# The hook reads two jq fields. Keep the mock query handling explicit.
cat >"$tmp/bin/jq" <<'MOCK'
#!/usr/bin/env python3
import json,sys
field=sys.argv[2].split()[0].removeprefix('.')
print(json.load(sys.stdin).get(field, ''))
MOCK
chmod +x "$tmp/bin/mock" "$tmp/bin/jq"
cat >"$tmp/bin/flock" <<'MOCK'
#!/usr/bin/env bash
if [[ -n ${MOCK_DELAY_READY:-} ]]; then
  printf 'ready\n' >"$MOCK_DELAY_READY"
  read -r release <"$MOCK_DELAY_GO"
fi
exec "$REAL_FLOCK" "$@"
MOCK
chmod +x "$tmp/bin/flock"
for command in tmux notify-send paplay; do ln -s mock "$tmp/bin/$command"; done
cat >"$HOME/.config/tmux/agent-status-lines.sh" <<'MOCK'
#!/usr/bin/env bash
echo status-refresh >>"$MOCK_LOG"
MOCK
chmod +x "$HOME/.config/tmux/agent-status-lines.sh"
hook="$root/.cursor/hooks/agent-tmux.sh"
explicit=(--pane %7 --session ses_a --client client-a --generation 100)
checks=0
check() {
  local label=$1
  shift
  : >"$MOCK_LOG"
  "$@" <"$tmp/payload" >"$tmp/out" 2>"$tmp/err" || { echo "FAIL: $label" >&2; cat "$tmp/err" >&2; exit 1; }
  checks=$((checks + 1))
  echo "ok $checks - $label"
}
contains() { grep -Fq -- "$1" "$MOCK_LOG" || { echo "Missing: $1" >&2; cat "$MOCK_LOG" >&2; exit 1; }; }
absent() { if grep -Fq -- "$1" "$MOCK_LOG"; then echo "Unexpected: $1" >&2; cat "$MOCK_LOG" >&2; exit 1; fi; }
echo '{}' >"$tmp/payload"
check 'OpenCode binding uses the explicit pane without notifications' env TMUX_PANE=%99 "$hook" bind opencode "${explicit[@]}"
contains '<set-option> <-p> <-t> <%7> <@opencode-binding> <ses_a|100|client-a>'
absent '<@agent-state>'
absent notify-send
absent '<%99>'
for state in running needs-input done off; do
  check "OpenCode $state uses only its bound pane" env TMUX_PANE=%99 "$hook" "$state" opencode "${explicit[@]}"
  contains "<set-option> <-p> <-t> <%7> <@agent-state> <$state>"
  contains "<set-option> <-w> <-t> <%7> <@agent-state> <$state>"
  contains '<@agent-name> <opencode>'
  contains status-refresh
  absent '<%99>'
  absent '<%8>'
  case "$state" in
    running | off) absent notify-send; absent '<display-message> <-c>' ;;
    needs-input) contains 'notify-send <-u> <critical>'; contains '<display-message> <-c> <client-1>' ;;
    done) contains 'notify-send <-u> <normal>'; contains '<display-message> <-c> <client-1>' ;;
  esac
done
check 'quiet state restore keeps hints without notifications' "$hook" done opencode "${explicit[@]}" --quiet
contains '<@agent-state> <done>'
absent notify-send
absent '<display-message> <-c>'
check 'stale session does not set state or notify' env MOCK_BINDING='ses_b|100|client-a' "$hook" done opencode "${explicit[@]}"
absent '<set-option>'
absent notify-send
absent status-refresh
check 'old plugin cleanup cannot clear a new client binding' env MOCK_BINDING='ses_a|200|client-new' "$hook" off opencode "${explicit[@]}"
absent '<set-option>'
check 'binding lookup failure does not notify' env MOCK_BINDING_FAIL=1 "$hook" done opencode "${explicit[@]}"
absent '<set-option>'
absent notify-send
check 'OpenCode cannot use an inherited pane without binding arguments' env TMUX_PANE=%99 "$hook" done opencode
absent tmux
absent notify-send
check 'invalid explicit pane does not run tmux' "$hook" done opencode --pane bad --session ses_a --client client-a --generation 100
absent tmux
check 'missing explicit option value is safe' "$hook" done opencode --pane
absent tmux
check 'invalid lock directory does not notify or update a pane' env XDG_RUNTIME_DIR="$tmp/missing" "$hook" done opencode "${explicit[@]}"
absent '<set-option>'
absent notify-send
exec 8>"$tmp/opencode-tmux-pane-7.lock"
flock 8
check 'held pane lock prevents a concurrent client rebind' "$hook" bind opencode --pane %7 --session ses_b --client client-b --generation 200
absent '<set-option>'
flock -u 8
exec 8>&-
check 'an obsolete bind cannot replace a newer generation' env MOCK_BINDING='ses_b|200|client-b' "$hook" bind opencode "${explicit[@]}"
absent '<set-option>'
check 'generation comparison handles wider decimal values without overflow' env MOCK_BINDING='ses_b|999999999999999999999999|client-b' "$hook" bind opencode "${explicit[@]}"
absent '<set-option>'
check 'a generation tie cannot replace another client' env MOCK_BINDING='ses_b|100|client-b' "$hook" bind opencode "${explicit[@]}"
absent '<set-option>'
delayed_bind_regression() {
  local old_pid new_binding
  : >"$tmp/binding"
  mkfifo "$tmp/old-ready" "$tmp/old-go"
  env MOCK_BINDING_FILE="$tmp/binding" MOCK_DELAY_READY="$tmp/old-ready" MOCK_DELAY_GO="$tmp/old-go" \
    "$hook" bind opencode "${explicit[@]}" <"$tmp/payload" &
  old_pid=$!
  read -r ready <"$tmp/old-ready"
  env MOCK_BINDING_FILE="$tmp/binding" "$hook" bind opencode --pane %7 --session ses_b --client client-b --generation 200 <"$tmp/payload"
  new_binding=$(cat "$tmp/binding")
  : >"$MOCK_LOG"
  printf 'go\n' >"$tmp/old-go"
  wait "$old_pid" || return 1
  [[ "$new_binding" == 'ses_b|200|client-b' && "$(cat "$tmp/binding")" == "$new_binding" ]] || return 1
  absent '<set-option>'
  env MOCK_BINDING_FILE="$tmp/binding" "$hook" off opencode "${explicit[@]}" <"$tmp/payload"
  absent '<@agent-state>'
  env MOCK_BINDING_FILE="$tmp/binding" "$hook" running opencode --pane %7 --session ses_b --client client-b --generation 200 <"$tmp/payload"
  contains '<set-option> <-p> <-t> <%7> <@agent-state> <running>'
}
check 'old bind delayed before the lock cannot replace the new owner or clear its hints' delayed_bind_regression
check 'unavailable tmux server does not fail the agent hook' env MOCK_TMUX_FAIL=1 "$hook" running opencode "${explicit[@]}"
absent '<set-option>'
check 'tmux write failure does not fail the agent hook' env MOCK_SET_FAIL=1 "$hook" running opencode "${explicit[@]}"
for agent in claude cursor; do
  check "$agent retains local pane state and notification" env TMUX_PANE=%3 "$hook" done "$agent"
  contains '<set-option> <-p> <-t> <%3> <@agent-state> <done>'
  contains "<@agent-name> <$agent>"
  contains 'notify-send <-u> <normal>'
  absent @opencode-binding
done
check 'legacy outside-pane fallback stays unchanged' env -u TMUX_PANE "$hook" running cursor
contains '<set-option> <-p> <-t> <%7>'
contains '<set-option> <-p> <-t> <%8>'
absent '<set-option> <-p> <-t> <%9>'
absent '<set-option> <-p> <-t> <%10>'
echo '{"status":"aborted"}' >"$tmp/payload"
check 'Cursor cancelled turn still skips notifications and state changes' env TMUX_PANE=%3 "$hook" done cursor
absent '<set-option>'
absent notify-send
echo '{}' >"$tmp/payload"

check 'jump keeps needs-input before done' "$root/.config/tmux/agent-jump.sh" client-1
contains '<switch-client> <-c> <client-1> <-t> <%8>'
check 'jump falls back to done' env MOCK_PANE_B=running "$root/.config/tmux/agent-jump.sh" client-1
contains '<switch-client> <-c> <client-1> <-t> <%7>'
check 'jump does not choose running panes' env MOCK_PANE_A=running MOCK_PANE_B=running "$root/.config/tmux/agent-jump.sh" client-1
contains '<display-message> <-c> <client-1> <no agents waiting>'
check 'OpenCode state shows a status line in another session' env MOCK_WINDOWS='$1 running' MOCK_SESSIONS=$'$1 \n$2 ' "$root/.config/tmux/agent-status-lines.sh"
contains '<set-option> <-t> <$1> <-u> <status>'
contains '<set-option> <-t> <$2> <status> <2>'
check 'tree mode retains its key hints without agent activity' env MOCK_WINDOWS='$1 off' MOCK_SESSIONS=$'$1 tree-mode\n$2 ' "$root/.config/tmux/agent-status-lines.sh"
contains '<set-option> <-t> <$1> <status> <2>'
contains '<set-option> <-t> <$2> <-u> <status>'
echo "PASS: $checks mock tmux hook and hint tests"
