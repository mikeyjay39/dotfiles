#!/usr/bin/env bash
set -Eeuo pipefail

stow -d ${HOME}/dotfiles -t ~ . --adopt

