#!/usr/bin/env bash
# Shared CLI detection. Source this file; do not start an agent here.
is_agent_program() {
  case "$(basename -- "$1")" in
    claude | cursor-agent | agent | opencode) return 0 ;;
    *) return 1 ;;
  esac
}

detect_agent() {
  local pid=$$ program
  while [[ "$pid" =~ ^[0-9]+$ ]] && (( pid > 1 )); do
    program=$(basename -- "$(ps -o args= -p "$pid" | awk '{print $1}')")
    case "$program" in
      claude) echo claude; return ;;
      cursor-agent | agent) echo cursor; return ;;
      opencode) echo opencode; return ;;
    esac
    pid=$(ps -o ppid= -p "$pid" | tr -d ' ')
  done
  echo 'Cannot detect the boss CLI. Pass --agent claude|cursor|opencode. OpenCode tools use a shared server.' >&2
  return 1
}
