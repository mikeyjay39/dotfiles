#!/usr/bin/env bash
set -Eeuo pipefail

pacman -S --noconfirm \
	 rustup

rustup toolchain install stable
rustup default stable
rustup component add rust-analyzer

yay -S --noconfirm \
	codelldb-bin
