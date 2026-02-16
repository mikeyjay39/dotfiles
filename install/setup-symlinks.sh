#!/usr/bin/env bash
set -Eeuo pipefail

stow -d ~/dotfiles -t ~ . --adopt

