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
