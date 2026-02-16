#!/usr/bin/env bash
set -Eeuo pipefail

pacman -S --noconfirm \
	 rustup

rustup component add rust-analyzer
