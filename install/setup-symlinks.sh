#!/usr/bin/env bash
set -Eeuo pipefail

stow -d ${HOME}/dotfiles -t ~ . --adopt

# setup cursor commands
mkdir -p ${HOME}/.cursor/commands
for command in ${HOME}/dotfiles/.cursor/commands/*; do
  target_link="${HOME}/.cursor/$(basename "$command")"
  if [ ! -L "$target_link" ]; then
    ln -s "$command" "$target_link"
  fi
done

# Cursor agent notify hooks (tmux + notify-send)
# The ~/.cursor/hooks.json symlink is user-level config. Command paths must still
# be cwd-proof: a session whose workspace is $HOME loads this same file as
# *project* hooks and runs them from ~, so ./hooks/agent-tmux.sh misses.
# hooks.json therefore calls $HOME/.cursor/hooks/agent-tmux.sh (this symlink).
mkdir -p "${HOME}/.cursor/hooks"
ln -sfn "${HOME}/dotfiles/.cursor/hooks.json" "${HOME}/.cursor/hooks.json"
ln -sfn "${HOME}/dotfiles/.cursor/hooks/agent-tmux.sh" "${HOME}/.cursor/hooks/agent-tmux.sh"
chmod +x "${HOME}/dotfiles/.cursor/hooks/agent-tmux.sh"

# Claude Code hooks (same notify script); merge carefully if settings already exist
mkdir -p "${HOME}/.claude"
if [ ! -e "${HOME}/.claude/settings.json" ]; then
  ln -s "${HOME}/dotfiles/.claude/settings.json" "${HOME}/.claude/settings.json"
elif [ -L "${HOME}/.claude/settings.json" ]; then
  ln -sfn "${HOME}/dotfiles/.claude/settings.json" "${HOME}/.claude/settings.json"
fi
